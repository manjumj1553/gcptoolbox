/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "zone" {
  type = string
}

variable "project_id" {
  type = string
}

variable "project_number" {
  type = string
}

variable "basename" {
  type = string
}

variable "region" {
  type = string
}

variable "username" {
  type = string
}

variable "privatekeypath" {
    type = string
    default = "./id_rsa"
}

variable "publickeypath" {
    type = string
    default = "./id_rsa.pub"
}

locals {
  sacompute = "${var.project_number}-compute@developer.gserviceaccount.com"
}

# Enabling services in your GCP project
variable "gcp_service_list" {
  description = "The list of apis necessary for the project"
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "osconfig.googleapis.com",
  ]
}

resource "google_project_service" "all" {
  for_each                   = toset(var.gcp_service_list)
  project                    = var.project_number
  service                    = each.key
  disable_dependent_services = false
  disable_on_destroy         = false
}



// Terraform plugin for creating random ids
resource "random_id" "instance_id" {
  byte_length = 8
}

# We create a public IP address for our google compute instance to utilize
resource "google_compute_address" "static" {
  name = "jump-vm-public-address"
  project = var.project_id
  region = var.region
}

// A Single Compute Engine instance
resource "google_compute_instance" "default" {
  project      = var.project_id
  name         = "${var.basename}-instance"
  machine_type = "n1-standard-2"
  zone         = var.zone

  tags = ["http-server","https-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11-bullseye-v20220920"
    }
  }
  labels = {
    env        = "dev"
    app        = "demosapjump"
    created_by = "terraform"
  }

  network_interface {
    network = "pso-sap-vpc"
    subnetwork = "sap-sn-01"
    access_config {
	    nat_ip = google_compute_address.static.address
    }
  }

  # This is copy the the SSH public Key to enable the SSH Key based authentication
  metadata = {
    ssh-keys = "${var.username}:${file(var.publickeypath)}"
  }

  provisioner "remote-exec" {
    connection {
      host        = google_compute_address.static.address 
      type        = "ssh"
      user        = var.username
      timeout     = "500s"
      private_key = file(var.privatekeypath)
    }
    inline = [
      "sudo apt-get -y install unzip",
      "sudo apt-get -y install git",
      "sudo apt-get -y install google-cloud-secret-manager",
      "sudo apt-get -y install python3",
    ]
  }

  service_account {
    // Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    // This non production example uses the default compute service account.
    email  = local.sacompute
    scopes = ["cloud-platform"]
  }
}

// Cloud Ops Agent Policy
module "agent_policy" {
  source  = "terraform-google-modules/cloud-operations/google//modules/agent-policy"
  version = "~> 0.2.3"

  project_id = var.project_id
  policy_id  = "ops-agents-example-policy"
  agent_rules = [
    {
      type               = "ops-agent"
      version            = "current-major"
      package_state      = "installed"
      enable_autoupgrade = true
    },
  ]
  group_labels = [
    {
    	env        = "dev"
    	app        = "demosapjump"
    	created_by = "terraform"
    }
  ]

  os_types = [
    {
      short_name = "debian"
      version    = "11"
    },
  ]
}

output "instance_id" {
  value = google_compute_instance.default.instance_id
}
