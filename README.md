Opentofu repository to create a kubernetes cluster on proxmox

Rename and fill variables.auto.tfvars.example to variables.auto.tfvars

tofu plan
tofu apply

TOFIX:
- Code assume proxmox network 192.168.1.0/24 (in case change on k8s-vm...)
- While multiple worker is supported, code failed to create multiple control plane node

CREDITS:
Most of the code is taken from https://blog.stonegarden.dev/articles/2024/03/proxmox-k8s-with-cilium/
