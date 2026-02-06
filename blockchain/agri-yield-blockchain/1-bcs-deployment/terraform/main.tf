terraform {
  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = ">= 1.40.0"
    }
  }
}

provider "huaweicloud" {
  region = var.region
}

# IAM Configuration (Section 1.2.1)
resource "huaweicloud_identity_user" "bcs_admin" {
  name     = "agri-yield-admin"
  enabled  = true
}

resource "huaweicloud_identity_group" "bcs_admins" {
  name = "bcs-admin-group"
}

resource "huaweicloud_identity_group_membership" "admin_membership" {
  group = huaweicloud_identity_group.bcs_admins.id
  users = [huaweicloud_identity_user.bcs_admin.id]
}

# Custom Policy (Section 1.2.2)
resource "huaweicloud_identity_agency" "bcs_admin_trust" {
  name                   = "bcs_admin_trust"
  delegated_service_name = "op_svc_bcs"
  project_role {
    project = data.huaweicloud_identity_projects.current.projects[0].id
    roles   = ["Tenant Administrator", "Server Administrator", "VPC Administrator"]
  }
}

# CCE Cluster (Section 1.3.1 prerequisites)
resource "huaweicloud_cce_cluster" "agri_cluster" {
  name                   = "agri-yield-cluster"
  flavor_id              = "cce.s2.small"
  vpc_id                 = huaweicloud_vpc.agri_vpc.id
  subnet_id              = huaweicloud_vpc_subnet.agri_subnet.id
  container_network_type = "overlay_l2"
  authentication_mode    = "rbac"
  
  tags = {
    environment = "production"
    project     = "agri-yield"
  }
}

resource "huaweicloud_cce_node" "cluster_nodes" {
  count        = var.node_count
  cluster_id   = huaweicloud_cce_cluster.agri_cluster.id
  name         = "agri-node-${count.index}"
  flavor_id    = "s6.large.2"
  availability_zone = "ap-southeast-1a"
  
  root_volume {
    size       = 100
    volumetype = "SSD"
  }
  
  data_volumes {
    size       = 200
    volumetype = "SSD"
  }
  
  key_pair = huaweicloud_compute_keypair.agri_keypair.name
}

# BCS Instance (Professional Edition)
resource "huaweicloud_bcs_instance" "agri_blockchain" {
  name          = "agri-yield-blockchain"
  edition       = "4"
  consensus     = "fbft"
  fabric_version = "2.2"
  blockchain_type = "consortium"
  
  # CCE Cluster
  cluster_id    = huaweicloud_cce_cluster.agri_cluster.id
  
  # Organizations
  peer_orgs {
    org_name   = "FarmerOrg"
    peer_count = 2
  }
  
  peer_orgs {
    org_name   = "BankOrg"
    peer_count = 2
  }
  
  peer_orgs {
    org_name   = "ExchangeOrg"
    peer_count = 2
  }
  
  # Channels
  channels {
    name        = "yield-channel"
    org_names   = ["FarmerOrg", "ExchangeOrg"]
  }
  
  channels {
    name        = "loan-channel"
    org_names   = ["FarmerOrg", "BankOrg"]
  }
  
  channels {
    name        = "audit-channel"
    org_names   = ["FarmerOrg", "BankOrg", "ExchangeOrg"]
  }
  
  # Storage
  volume_type  = "nfs"
  org_disk_size = 500
  
  # Security
  security_mechanism = "ECDSA"
  orderer_node_number = 4
  
  # Block generation
  block_generation {
    transaction_quantity = 1000
    block_size          = 2
    generate_block_time = 2
  }
  
  # REST API Enabled
  restapi_enabled = true
  
  # EIP Configuration
  eip_enable     = true
  bandwidth_size = 10
  
  # Backup
  is_auto_renew  = true
  is_backup      = true
  backup_interval = 86400
  
  tags = {
    project = "agriculture-tokenization"
  }
}

# VPC and Networking
resource "huaweicloud_vpc" "agri_vpc" {
  name = "agri-yield-vpc"
  cidr = "10.0.0.0/16"
}

resource "huaweicloud_vpc_subnet" "agri_subnet" {
  vpc_id      = huaweicloud_vpc.agri_vpc.id
  name        = "agri-yield-subnet"
  cidr        = "10.0.1.0/24"
  gateway_ip  = "10.0.1.1"
}

# Key Pair for SSH
resource "huaweicloud_compute_keypair" "agri_keypair" {
  name = "agri-yield-keypair"
}

# Data source for project ID
data "huaweicloud_identity_projects" "current" {
}

# Outputs
output "bcs_instance_id" {
  value = huaweicloud_bcs_instance.agri_blockchain.id
  description = "BCS Instance ID"
}

output "cluster_id" {
  value = huaweicloud_cce_cluster.agri_cluster.id
  description = "CCE Cluster ID"
}

output "cluster_name" {
  value = huaweicloud_cce_cluster.agri_cluster.name
  description = "CCE Cluster Name"
}

output "vpc_id" {
  value = huaweicloud_vpc.agri_vpc.id
  description = "VPC ID"
}

output "subnet_id" {
  value = huaweicloud_vpc_subnet.agri_subnet.id
  description = "Subnet ID"
}

output "bcs_endpoints" {
  value = {
    rest_api   = huaweicloud_bcs_instance.agri_blockchain.restapi_address
    grpc       = huaweicloud_bcs_instance.agri_blockchain.grpc_address
    web        = huaweicloud_bcs_instance.agri_blockchain.web_address
  }
  description = "BCS Connection Endpoints"
}
