# k8s-vm-control-plane.tf
resource "proxmox_virtual_environment_vm" "k8s-ctrl" {
  provider  = proxmox.euclid
  node_name = var.euclid.node_name

  count	      = var.master_nodes
  name        = "k8s-ctrl-${format("%02d",count.index)}"
  description = "Kubernetes Control Plane 01"
  tags        = ["k8s", "control-plane"]
  on_boot     = true
  vm_id       = "80${format("%02d",count.index)}"

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  bios          = "ovmf"

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:2E:C0:01"
  }

  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw" // To support qcow2 format
    type         = "4m"
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.debian_12_generic_image.id
    interface    = "scsi0"
    cache        = "writethrough"
    discard      = "on"
    ssd          = true
    size         = 32
  }

  boot_order = ["scsi0"]

  agent {
    enabled = true
  }

  operating_system {
    type = "l26" # Linux Kernel 2.6 - 6.X.
  }

  initialization {
    dns {
      domain  = var.vm_dns.domain
      servers = var.vm_dns.servers
    }
    ip_config {
      ipv4 {
        address = "192.168.1.1${format("%02d",count.index)}/24"
        gateway = "192.168.1.1"
      }
    }

    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.cloud-init-ctrl-01.id
  }
}

output "ctrl_ipv4_address" {
  depends_on = [proxmox_virtual_environment_vm.k8s-ctrl]
  #value      = join(" ",proxmox_virtual_environment_vm.k8s-ctrl.ipv4_addresses[1][0])
  value      = [for i in proxmox_virtual_environment_vm.k8s-ctrl : i.ipv4_addresses[1][0]]
}

resource "local_file" "ctrl-ip" {
  count		  = var.master_nodes 
  content         = proxmox_virtual_environment_vm.k8s-ctrl[count.index].ipv4_addresses[1][0]
  filename        = "output/ctrl-${format("%02d",count.index)}-ip.txt"
  file_permission = "0644"
}

module "kube-config" {
  count	       = var.worker_nodes 
  depends_on   = [local_file.ctrl-ip]
  source       = "Invicton-Labs/shell-resource/external"
  version      = "0.4.1"
  command_unix = "ssh -o StrictHostKeyChecking=no ${var.vm_user}@${local_file.ctrl-ip[0].content} cat /home/${var.vm_user}/.kube/config"
}

resource "local_file" "kube-config" {
  count	          = var.worker_nodes 
  content         = module.kube-config[count.index].stdout
  filename        = "output/config"
  file_permission = "0600"
}

module "kubeadm-join" {
  count	       = var.worker_nodes 
  depends_on   = [local_file.kube-config]
  source       = "Invicton-Labs/shell-resource/external"
  version      = "0.4.1"
  command_unix = "ssh -o StrictHostKeyChecking=no ${var.vm_user}@${local_file.ctrl-ip[0].content} /usr/bin/kubeadm token create --print-join-command"
}
