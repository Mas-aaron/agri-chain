output "bcs_instance_id" {
  value       = huaweicloud_bcs_instance.agri_blockchain.id
  description = "BCS Instance ID for SDK configuration"
}

output "cluster_id" {
  value       = huaweicloud_cce_cluster.agri_cluster.id
  description = "CCE Cluster ID"
}

output "cluster_name" {
  value       = huaweicloud_cce_cluster.agri_cluster.name
  description = "CCE Cluster name"
}

output "vpc_id" {
  value       = huaweicloud_vpc.agri_vpc.id
  description = "VPC ID for all resources"
}

output "subnet_id" {
  value       = huaweicloud_vpc_subnet.agri_subnet.id
  description = "Subnet ID for network resources"
}

output "keypair_name" {
  value       = huaweicloud_compute_keypair.agri_keypair.name
  description = "SSH key pair name"
}

output "bcs_rest_api_endpoint" {
  value       = huaweicloud_bcs_instance.agri_blockchain.restapi_address
  description = "BCS REST API endpoint"
  sensitive   = true
}

output "bcs_grpc_endpoint" {
  value       = huaweicloud_bcs_instance.agri_blockchain.grpc_address
  description = "BCS gRPC endpoint for SDK"
  sensitive   = true
}

output "bcs_web_endpoint" {
  value       = huaweicloud_bcs_instance.agri_blockchain.web_address
  description = "BCS Web console endpoint"
}

output "deployment_summary" {
  value = {
    region              = var.region
    bcs_instance_id     = huaweicloud_bcs_instance.agri_blockchain.id
    cluster_name        = huaweicloud_cce_cluster.agri_cluster.name
    node_count          = var.node_count
    fabric_version      = var.fabric_version
    consensus           = var.consensus_type
    environment         = var.environment
    deployment_status   = "Success"
  }
  description = "Complete deployment summary"
}
