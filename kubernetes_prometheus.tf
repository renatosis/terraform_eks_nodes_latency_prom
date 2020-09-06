
resource "kubernetes_namespace" "prometheus" {
  metadata {
    annotations = {
      name = "prometheus"
    }
    labels = {
      promlabel = "prometheus"
    }
    name = "prometheus"
  }
}

resource "kubernetes_config_map" "prometheus" {
  metadata {
    name = "prometheus-config"
    namespace = "prometheus"
  }

  data = {
    "prometheus.yml" = "${file("${path.module}/config/prometheus.yml")}"
  }
}

resource "kubernetes_service" "prometheus" {
  metadata {
    name = "prometheus"
    namespace = "prometheus"
  }
  spec {
    selector = {
      "app" = "prometheus"
    }
    type = "LoadBalancer"
    port {
      protocol = "TCP"
      port = 9090
      target_port = "value"
    }
  }
}

resource "kubernetes_service_account" "prometheus" {
  metadata {
    name = "prometheus"
    namespace = "prometheus"
  }
}

resource "kubernetes_deployment" "prometheus" {
  metadata {
    name = "prometheus"
    namespace = "prometheus"
    labels = {
      promlabel = "prometheus"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "prometheus"
      }
    }

    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }

      spec {
        service_account_name = "prometheus"
        container {
          name = "prometheus"
          image = "prom/prometheus:v2.20.1"
          port {
            container_port = 9090
            name = "default"
          }
          volume_mount {
            name = "config-volume"
            mount_path = "/etc/prometheus"
          }
        }
        volume {
          name = "config-volume"
          config_map {
            name = "prometheus-config"
          }
        }
      }
    }
  }
}

resource "kubernetes_cluster_role" "example" {
  metadata {
    name = "prometheus"
  }
  rule {
    api_groups = [""]
    resources  = ["nodes/metrics", "pods", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups  = ["extensions"]
    resources   = ["ingresses"]
    verbs       = ["get", "list", "watch"]
  }
  rule {
    non_resource_urls = ["/metrics", "/metrics/cadvisor"]
    verbs = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "prometheus" {
  metadata {
    name = "prometheus"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind = "ClusterRole"
    name = "prometheus"
  }
  subject {
    kind = "ServiceAccount"
    name = "prometheus"
    namespace = "prometheus"
  }
}
