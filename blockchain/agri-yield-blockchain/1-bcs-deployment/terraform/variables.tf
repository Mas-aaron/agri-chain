variable "region" {
  description = "Huawei Cloud region"
  type        = string
  default     = "ap-southeast-1"
}

variable "node_count" {
  description = "Number of CCE cluster nodes"
  type        = number
  default     = 3
  validation {
    condition     = var.node_count >= 1 && var.node_count <= 10
    error_message = "Node count must be between 1 and 10."
  }
}

variable "bcs_edition" {
  description = "BCS edition (Professional=4, Standard=2)"
  type        = number
  default     = 4
}

variable "fabric_version" {
  description = "Hyperledger Fabric version"
  type        = string
  default     = "2.2"
}

variable "consensus_type" {
  description = "Consensus algorithm (fbft, raft)"
  type        = string
  default     = "fbft"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "AgriYield"
    Owner       = "Platform Team"
    ManagedBy   = "Terraform"
  }
}
