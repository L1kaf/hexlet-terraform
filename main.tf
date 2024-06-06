terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    datadog = {
      source = "DataDog/datadog"
    }
  }
  required_version = ">= 0.13"
}

// Terraform должен знать ключ, для выполнения команд по API

// Определение переменной, которую нужно будет задать
variable "yc_token" {
  type = string
  sensitive = true
}

variable "folder_id" {
  type = string
  sensitive = true
}

variable "yc_account_id" {
  type = string
  sensitive = true
}

provider "yandex" {
  zone = "ru-central1-a"
  token = var.yc_token
  folder_id = var.folder_id
}


resource "yandex_compute_instance_group" "yandex-student-instance-group" {
  name = "nlb-vm-group"
  service_account_id = var.yc_account_id

  instance_template {
    platform_id = "standard-v1"

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = "fd8bkgba66kkf9eenpkb"
        type     = "network-hdd"
        size     = 8
      }
    }

    network_interface {
      network_id = yandex_vpc_network.network-1.id
      subnet_ids = [yandex_vpc_subnet.subnet-1.id, yandex_vpc_subnet.subnet-2.id]
      nat        = true
    }

    resources {
      core_fraction = 5
      cores         = 2
      memory        = 2
    }

    # прерываемая
    scheduling_policy {
      preemptible = true
    }


  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }

  load_balancer {
    target_group_name = "yandex-student-target-group"
  }
}


resource "yandex_vpc_network" "network-1" {
  name = "yandex-student-network"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "yandex-student-subnet-1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.1.0/24"]
}

resource "yandex_vpc_subnet" "subnet-2" {
  name           = "yandex-student-subnet-2"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.2.0/24"]
}

resource "yandex_lb_network_load_balancer" "balancer" {
  name = "balanser-test"
  listener {
    name        = "yandex-student-listener"
    port        = 80
    target_port = 80
  }
  attached_target_group {
    target_group_id = yandex_compute_instance_group.yandex-student-instance-group.load_balancer.0.target_group_id
    healthcheck {
      name                = "health-check-1"
      unhealthy_threshold = 5
      healthy_threshold   = 5
      http_options {
        port = 80
      }
    }
  }
}


variable "datadog_api_key" {
  type      = string
  sensitive = true
}

variable "datadog_app_key" {
  type      = string
  sensitive = true
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.datadoghq.eu/"
}