resource "helm_release" "monitoring" {
  name             = "monitoring"
  chart            = "../../charts/monitoring"
  namespace        = "monitoring"
  create_namespace = true
  depends_on       = [var.eks_cluster_endpoint]
}