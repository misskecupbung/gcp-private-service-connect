terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "google_compute_network" "vpc_main" {
  name                    = "vpc-main"
  auto_create_subnetworks = false
  description             = "Main VPC for PSC demo"
}

# -----------------------------------------------------------------------------
# Subnet
# -----------------------------------------------------------------------------
resource "google_compute_subnetwork" "subnet_main" {
  name          = "subnet-main"
  ip_cidr_range = "10.1.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_main.id
}

# -----------------------------------------------------------------------------
# Firewall Rules - IAP SSH
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "allow_iap" {
  name    = "allow-iap-ssh"
  network = google_compute_network.vpc_main.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
}

# -----------------------------------------------------------------------------
# Test VM
# -----------------------------------------------------------------------------
resource "google_compute_instance" "test_vm" {
  name         = "test-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_main.id
    subnetwork = google_compute_subnetwork.subnet_main.id
    # No external IP - all traffic through private endpoints
  }

  metadata_startup_script = file("${path.module}/../scripts/startup-test.sh")

  tags = ["test-server"]
}

# -----------------------------------------------------------------------------
# Private Service Connect - Google APIs
# -----------------------------------------------------------------------------
resource "google_compute_address" "psc_address" {
  name         = "psc-google-apis-ip"
  region       = var.region
  subnetwork   = google_compute_subnetwork.subnet_main.id
  address_type = "INTERNAL"
  address      = "10.1.0.100"
}

resource "google_compute_forwarding_rule" "psc_google_apis" {
  name                  = "psc-google-apis"
  region                = var.region
  network               = google_compute_network.vpc_main.id
  ip_address            = google_compute_address.psc_address.id
  target                = "all-apis"
  load_balancing_scheme = ""
}

# -----------------------------------------------------------------------------
# Private DNS Zone for Google APIs
# -----------------------------------------------------------------------------
resource "google_dns_managed_zone" "googleapis_private" {
  name        = "googleapis-private"
  dns_name    = "googleapis.com."
  description = "Private DNS zone for Google APIs via PSC"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc_main.id
    }
  }
}

resource "google_dns_record_set" "storage_googleapis" {
  name         = "storage.googleapis.com."
  managed_zone = google_dns_managed_zone.googleapis_private.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.psc_address.address]
}

resource "google_dns_record_set" "bigquery_googleapis" {
  name         = "bigquery.googleapis.com."
  managed_zone = google_dns_managed_zone.googleapis_private.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.psc_address.address]
}

resource "google_dns_record_set" "pubsub_googleapis" {
  name         = "pubsub.googleapis.com."
  managed_zone = google_dns_managed_zone.googleapis_private.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.psc_address.address]
}

resource "google_dns_record_set" "wildcard_googleapis" {
  name         = "*.googleapis.com."
  managed_zone = google_dns_managed_zone.googleapis_private.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.psc_address.address]
}
