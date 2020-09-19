provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "kconmon" {
  name      = "kconmon"
  chart     = "${path.module}/helm/kconmon"
  namespace = "prometheus"
}