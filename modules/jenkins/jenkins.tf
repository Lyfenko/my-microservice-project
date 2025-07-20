resource "helm_release" "jenkins" {
  name             = "jenkins"
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  version          = "5.8.68"
  namespace        = "jenkins"
  create_namespace = true
  timeout          = 600  # Збільшено до 10 хвилин
  values = [
    <<-EOT
    controller:
      persistence:
        enabled: true
        size: 10Gi
      admin:
        password: "admin"
      serviceType: LoadBalancer
      resources:
        requests:
          memory: "256Mi"
          cpu: "50m"
        limits:
          memory: "2Gi"  # Зменшено з 4Gi
          cpu: "1"      # Зменшено з 2
    EOT
  ]
}