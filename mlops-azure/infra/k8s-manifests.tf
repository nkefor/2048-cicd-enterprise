# Kubernetes Provider Configuration
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.mlops.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.mlops.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.mlops.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.mlops.kube_config[0].cluster_ca_certificate)
}

# Namespace for ML models
resource "kubernetes_namespace" "mlops" {
  metadata {
    name = "mlops"

    labels = {
      name        = "mlops"
      environment = var.environment
    }
  }

  depends_on = [azurerm_kubernetes_cluster.mlops]
}

# ConfigMap for model configuration
resource "kubernetes_config_map" "model_config" {
  metadata {
    name      = "model-config"
    namespace = kubernetes_namespace.mlops.metadata[0].name
  }

  data = {
    "app-insights-key"     = azurerm_application_insights.mlops.instrumentation_key
    "cosmos-db-endpoint"   = azurerm_cosmosdb_account.mlops.endpoint
    "storage-account-name" = azurerm_storage_account.mlops.name
  }

  depends_on = [kubernetes_namespace.mlops]
}

# Secret for sensitive configuration
resource "kubernetes_secret" "model_secrets" {
  metadata {
    name      = "model-secrets"
    namespace = kubernetes_namespace.mlops.metadata[0].name
  }

  data = {
    cosmos-db-key          = azurerm_cosmosdb_account.mlops.primary_key
    storage-account-key    = azurerm_storage_account.mlops.primary_access_key
    app-insights-conn-str  = azurerm_application_insights.mlops.connection_string
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.mlops]
}

# Deployment for Model A (Champion)
resource "kubernetes_deployment" "model_a" {
  metadata {
    name      = "model-a"
    namespace = kubernetes_namespace.mlops.metadata[0].name

    labels = {
      app     = "ml-model"
      version = "a"
      role    = "champion"
    }
  }

  spec {
    replicas = var.model_serving_replicas

    selector {
      match_labels = {
        app     = "ml-model"
        version = "a"
      }
    }

    template {
      metadata {
        labels = {
          app     = "ml-model"
          version = "a"
          role    = "champion"
        }
      }

      spec {
        container {
          name  = "model-server"
          image = "${azurerm_container_registry.mlops.login_server}/ml-model:latest"

          port {
            container_port = 8080
            name          = "http"
          }

          env {
            name = "MODEL_VERSION"
            value = "A"
          }

          env {
            name = "APPLICATIONINSIGHTS_CONNECTION_STRING"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.model_secrets.metadata[0].name
                key  = "app-insights-conn-str"
              }
            }
          }

          env {
            name = "COSMOS_DB_ENDPOINT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.model_config.metadata[0].name
                key  = "cosmos-db-endpoint"
              }
            }
          }

          env {
            name = "COSMOS_DB_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.model_secrets.metadata[0].name
                key  = "cosmos-db-key"
              }
            }
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "2000m"
              memory = "4Gi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.mlops,
    kubernetes_secret.model_secrets,
    kubernetes_config_map.model_config
  ]
}

# Deployment for Model B (Challenger)
resource "kubernetes_deployment" "model_b" {
  metadata {
    name      = "model-b"
    namespace = kubernetes_namespace.mlops.metadata[0].name

    labels = {
      app     = "ml-model"
      version = "b"
      role    = "challenger"
    }
  }

  spec {
    replicas = var.model_serving_replicas

    selector {
      match_labels = {
        app     = "ml-model"
        version = "b"
      }
    }

    template {
      metadata {
        labels = {
          app     = "ml-model"
          version = "b"
          role    = "challenger"
        }
      }

      spec {
        container {
          name  = "model-server"
          image = "${azurerm_container_registry.mlops.login_server}/ml-model:canary"

          port {
            container_port = 8080
            name          = "http"
          }

          env {
            name = "MODEL_VERSION"
            value = "B"
          }

          env {
            name = "APPLICATIONINSIGHTS_CONNECTION_STRING"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.model_secrets.metadata[0].name
                key  = "app-insights-conn-str"
              }
            }
          }

          env {
            name = "COSMOS_DB_ENDPOINT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.model_config.metadata[0].name
                key  = "cosmos-db-endpoint"
              }
            }
          }

          env {
            name = "COSMOS_DB_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.model_secrets.metadata[0].name
                key  = "cosmos-db-key"
              }
            }
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "2000m"
              memory = "4Gi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.mlops,
    kubernetes_secret.model_secrets,
    kubernetes_config_map.model_config
  ]
}

# Service for Model A
resource "kubernetes_service" "model_a" {
  metadata {
    name      = "model-a-service"
    namespace = kubernetes_namespace.mlops.metadata[0].name
  }

  spec {
    selector = {
      app     = "ml-model"
      version = "a"
    }

    port {
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.model_a]
}

# Service for Model B
resource "kubernetes_service" "model_b" {
  metadata {
    name      = "model-b-service"
    namespace = kubernetes_namespace.mlops.metadata[0].name
  }

  spec {
    selector = {
      app     = "ml-model"
      version = "b"
    }

    port {
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.model_b]
}

# LoadBalancer service for external access
resource "kubernetes_service" "ml_model_lb" {
  metadata {
    name      = "ml-model-service"
    namespace = kubernetes_namespace.mlops.metadata[0].name

    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/health"
    }
  }

  spec {
    selector = {
      app = "ml-model"
    }

    port {
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }

  depends_on = [
    kubernetes_deployment.model_a,
    kubernetes_deployment.model_b
  ]
}

# Horizontal Pod Autoscaler for Model A
resource "kubernetes_horizontal_pod_autoscaler_v2" "model_a_hpa" {
  metadata {
    name      = "model-a-hpa"
    namespace = kubernetes_namespace.mlops.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.model_a.metadata[0].name
    }

    min_replicas = 2
    max_replicas = 20

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.model_a]
}

# Horizontal Pod Autoscaler for Model B
resource "kubernetes_horizontal_pod_autoscaler_v2" "model_b_hpa" {
  metadata {
    name      = "model-b-hpa"
    namespace = kubernetes_namespace.mlops.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.model_b.metadata[0].name
    }

    min_replicas = 1
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.model_b]
}
