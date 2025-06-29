# Example Template Repository Structure

This directory contains example templates demonstrating the OpenTofu Infrastructure Abstraction Layer capabilities.

## Template Repository Structure

```
infrastructure-templates/
├── README.md
├── template.yaml                  # Repository metadata
├── base/                         # Base templates for inheritance
│   ├── network/
│   │   ├── template.yaml
│   │   └── main.tf
│   ├── security/
│   │   ├── template.yaml
│   │   └── main.tf
│   └── compute/
│       ├── template.yaml
│       └── main.tf
├── deployments/                  # Complete deployment templates
│   ├── hyperv-single-vm/
│   │   ├── template.yaml
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── hyperv-lab-basic/
│   │   ├── template.yaml
│   │   ├── main.tf
│   │   ├── network.tf
│   │   ├── vms.tf
│   │   └── variables.tf
│   └── hyperv-cluster/
│       ├── template.yaml
│       ├── main.tf
│       ├── cluster.tf
│       ├── storage.tf
│       └── variables.tf
└── modules/                      # Reusable OpenTofu modules
    ├── hyperv-vm/
    ├── virtual-switch/
    └── iso-management/
```

## Template Examples

### 1. Basic VM Deployment
- Single Windows Server 2025 VM
- Basic networking
- ISO automation

### 2. Lab Environment
- Domain Controller
- Member servers
- Isolated network
- Automated configuration

### 3. Hyper-V Cluster
- Multiple Hyper-V hosts
- Shared storage
- Failover clustering
- High availability

## Configuration Examples

### Simple Deployment
```yaml
version: 1.0
repository:
  url: "https://github.com/org/hyperv-templates"
  branch: "main"
template: "hyperv-single-vm"
parameters:
  vm_name: "TEST-VM-01"
  os_iso: "WindowsServer2025"
```

### Complex Lab
```yaml
version: 1.0
repository:
  url: "https://github.com/org/hyperv-templates"
  branch: "production"
template: "hyperv-lab-basic"
dependencies:
  - template: "base/network"
    version: ">=2.0.0"
  - template: "base/security"
    version: "~1.5.0"
iso_requirements:
  - name: "WindowsServer2025"
    customization: "lab-dc"
  - name: "WindowsServer2025"
    customization: "lab-member"
parameters:
  lab_name: "DEV-LAB-01"
  domain_name: "lab.local"
  network_range: "192.168.100.0/24"
```