# resource "helm_release" "mydatabase" {
#   name  = "mydatabase"
#   chart = "stable/mariadb"

#   set {
#     name  = "mariadbUser"
#     value = "foo"
#   }

#   set {
#     name  = "mariadbPassword"
#     value = "qux"
#   }
# }

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