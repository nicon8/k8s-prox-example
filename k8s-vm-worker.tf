# k8s-vm-worker.tf
resource "proxmox_virtual_environment_vm" "k8s-work" {
  provider  = proxmox.euclid
  node_name = var.euclid.node_name

  count       = var.worker_nodes 
  name        = "k8s-work-${format("%02d",count.index)}"
  description = "Kubernetes Worker ${format("%02d", count.index)}"
  tags        = ["k8s", "worker"]
  on_boot     = true
  vm_id       = "81${format("%02d", count.index)}"

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  bios          = "ovmf"

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:2E:AE:01"
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
        address = "192.168.1.11${count.index}/24"
        gateway = "192.168.1.1"
      }
    }

    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.cloud-init-work[count.index].id
  }

}

output "work_ipv4_address" {
  depends_on = [proxmox_virtual_environment_vm.k8s-work]
  #value      = proxmox_virtual_environment_vm.k8s-work[0].ipv4_addresses[1][0]
  value      = [for i in proxmox_virtual_environment_vm.k8s-work : i.ipv4_addresses[1][0]]
}

resource "local_file" "work-ip" {
  content         = join("\n",[for i in proxmox_virtual_environment_vm.k8s-work : i.ipv4_addresses[1][0]])
  #content         = proxmox_virtual_environment_vm.k8s-work[0].ipv4_addresses[1][0]
  filename        = "output/work-ip.txt"
  file_permission = "0644"
}
