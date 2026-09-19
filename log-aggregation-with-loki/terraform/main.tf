terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_network" "observability" {
  name = "observability-net"
}

resource "docker_volume" "loki_data" {
  name = "loki-data"
}

resource "docker_image" "loki" {
  name         = "grafana/loki:2.9.4"
  keep_locally = false
}

resource "docker_container" "loki" {
  name  = "loki"
  image = docker_image.loki.image_id
  ports {
    internal = 3100
    external = 3100
  }
  volumes {
    volume_name    = docker_volume.loki_data.name
    container_path = "/loki"
  }
  upload {
    content = file("${path.module}/../config/loki-config.yml")
    file    = "/etc/loki/local-config.yaml"
  }
  networks_advanced {
    name = docker_network.observability.name
  }
  command = ["-config.file=/etc/loki/local-config.yaml"]
  restart = "unless-stopped"
}

resource "docker_image" "promtail" {
  name         = "grafana/promtail:2.9.4"
  keep_locally = false
}

resource "docker_container" "promtail" {
  name  = "promtail"
  image = docker_image.promtail.image_id
  ports {
    internal = 9080
    external = 9080
  }
  volumes {
    host_path      = "/var/log"
    container_path = "/var/log"
  }
  volumes {
    host_path      = "/var/lib/docker/containers"
    container_path = "/var/lib/docker/containers"
    read_only      = true
  }
  upload {
    content = templatefile("${path.module}/../config/promtail-config.yml", {
      loki_url = "http://loki:3100"
    })
    file = "/etc/promtail/config.yml"
  }
  networks_advanced {
    name = docker_network.observability.name
  }
  command = ["-config.file=/etc/promtail/config.yml"]
  restart = "unless-stopped"
}

output "loki_endpoint" {
  value = "http://localhost:3100"
}