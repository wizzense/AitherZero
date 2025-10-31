# Terraform configuration for AitherZero PR preview environments

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  
  # Backend configuration for state management
  # Uncomment and configure for production use
  # backend "azurerm" {
  #   resource_group_name  = "aitherzero-terraform-state"
  #   storage_account_name = "aitherzerstate"
  #   container_name       = "tfstate"
  #   key                  = "preview-environments.tfstate"
  # }
}

provider "azurerm" {
  features {}
}

# Variables for PR environment configuration
variable "pr_number" {
  description = "Pull Request number"
  type        = string
}

variable "branch_name" {
  description = "Git branch name"
  type        = string
}

variable "commit_sha" {
  description = "Git commit SHA"
  type        = string
}

variable "environment" {
  description = "Environment name (preview, staging, production)"
  type        = string
  default     = "preview"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "instance_size" {
  description = "VM/Container instance size"
  type        = string
  default     = "Standard_B2s"
}

variable "auto_shutdown_time" {
  description = "Auto-shutdown time for cost optimization (HH:MM format, 24-hour)"
  type        = string
  default     = "20:00"
}

variable "ttl_hours" {
  description = "Time-to-live in hours before automatic cleanup"
  type        = number
  default     = 48
}

# Local variables
locals {
  environment_name = "pr-${var.pr_number}"
  resource_prefix  = "aitherzero-${local.environment_name}"
  
  common_tags = {
    Project       = "AitherZero"
    Environment   = var.environment
    PRNumber      = var.pr_number
    BranchName    = var.branch_name
    CommitSHA     = var.commit_sha
    ManagedBy     = "Terraform"
    TTL           = "${var.ttl_hours}h"
    AutoShutdown  = var.auto_shutdown_time
  }
}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group for PR environment
resource "azurerm_resource_group" "pr_environment" {
  name     = "${local.resource_prefix}-rg-${random_string.suffix.result}"
  location = var.location
  
  tags = local.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "pr_vnet" {
  name                = "${local.resource_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.pr_environment.location
  resource_group_name = azurerm_resource_group.pr_environment.name
  
  tags = local.common_tags
}

# Subnet
resource "azurerm_subnet" "pr_subnet" {
  name                 = "${local.resource_prefix}-subnet"
  resource_group_name  = azurerm_resource_group.pr_environment.name
  virtual_network_name = azurerm_virtual_network.pr_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "pr_nsg" {
  name                = "${local.resource_prefix}-nsg"
  location            = azurerm_resource_group.pr_environment.location
  resource_group_name = azurerm_resource_group.pr_environment.name
  
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"  # TODO: Restrict to GitHub Actions IP ranges or specific IPs
    destination_address_prefix = "*"
    description                = "Allow HTTP - Consider restricting source IPs for production"
  }
  
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"  # TODO: Restrict to GitHub Actions IP ranges or specific IPs
    destination_address_prefix = "*"
    description                = "Allow HTTPS - Consider restricting source IPs for production"
  }
  
  security_rule {
    name                       = "AllowSSH"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"  # TODO: Restrict to specific management IPs only
    destination_address_prefix = "*"
    description                = "Allow SSH - Restrict to specific IPs for production"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  tags = local.common_tags
}

# Public IP for Container Instance
resource "azurerm_public_ip" "pr_public_ip" {
  name                = "${local.resource_prefix}-pip"
  location            = azurerm_resource_group.pr_environment.location
  resource_group_name = azurerm_resource_group.pr_environment.name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = local.common_tags
}

# Container Instance for AitherZero
resource "azurerm_container_group" "aitherzero" {
  name                = "${local.resource_prefix}-aci"
  location            = azurerm_resource_group.pr_environment.location
  resource_group_name = azurerm_resource_group.pr_environment.name
  os_type             = "Linux"
  
  ip_address_type = "Public"
  dns_name_label  = "${local.environment_name}-${random_string.suffix.result}"
  
  container {
    name   = "aitherzero"
    image  = "aitherzero:latest"  # Replace with your container registry
    cpu    = "1.0"
    memory = "2.0"
    
    ports {
      port     = 80
      protocol = "TCP"
    }
    
    ports {
      port     = 443
      protocol = "TCP"
    }
    
    environment_variables = {
      AITHERZERO_NONINTERACTIVE = "true"
      AITHERZERO_CI             = "false"
      DEPLOYMENT_ENVIRONMENT    = var.environment
      PR_NUMBER                 = var.pr_number
      BRANCH_NAME               = var.branch_name
      COMMIT_SHA                = var.commit_sha
    }
  }
  
  tags = local.common_tags
}

# Outputs
output "environment_url" {
  description = "URL to access the PR environment"
  value       = "http://${azurerm_container_group.aitherzero.fqdn}"
}

output "public_ip" {
  description = "Public IP address of the environment"
  value       = azurerm_public_ip.pr_public_ip.ip_address
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.pr_environment.name
}

output "environment_name" {
  description = "Environment identifier"
  value       = local.environment_name
}

output "cleanup_after" {
  description = "Timestamp when environment should be cleaned up"
  value       = timeadd(timestamp(), "${var.ttl_hours}h")
}
