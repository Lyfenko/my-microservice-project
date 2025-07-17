resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "8.1.3"
  namespace        = "argocd"
  create_namespace = true

  values = [
    <<YAML
server:
  service:
    type: LoadBalancer
YAML
  ]
}
