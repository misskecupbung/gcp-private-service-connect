output "vpc_id" {
  description = "VPC ID"
  value       = google_compute_network.vpc_main.id
}

output "test_vm_internal_ip" {
  description = "Internal IP of test-vm"
  value       = google_compute_instance.test_vm.network_interface[0].network_ip
}

output "psc_endpoint_ip" {
  description = "Private Service Connect endpoint IP"
  value       = google_compute_address.psc_address.address
}

output "dns_zone_name" {
  description = "Private DNS zone name"
  value       = google_dns_managed_zone.googleapis_private.name
}
