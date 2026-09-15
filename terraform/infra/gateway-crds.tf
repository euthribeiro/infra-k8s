# =============================================================================
# CRDs da Gateway API.
#
# Os kinds Gateway/HTTPRoute (e os CRDs vended da AWS) NAO vem no chart do
# controller nem no chart da aplicacao. Sao instalados aqui, ANTES do
# helm_release do LB Controller (ver depends_on em addons.tf), para que o
# controller ja nasca com o sub-controller de Gateway habilitado - sem precisar
# de restart.
# =============================================================================

# CRDs padrao da Gateway API (Gateway, HTTPRoute, ...) na versao suportada pelo LBC.
data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml"
}

# CRDs "vended" da AWS (TargetGroupConfiguration, LoadBalancerConfiguration, ...).
data "http" "aws_gateway_crds" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml"
}

# Quebra os YAMLs multi-documento em manifestos individuais.
data "kubectl_file_documents" "gateway_api_crds" {
  content = data.http.gateway_api_crds.response_body
}

data "kubectl_file_documents" "aws_gateway_crds" {
  content = data.http.aws_gateway_crds.response_body
}

# server_side_apply e necessario: os CRDs da Gateway API sao grandes e o apply
# client-side estoura o limite de anotacao (metadata.annotations too long).
resource "kubectl_manifest" "gateway_api_crds" {
  for_each          = data.kubectl_file_documents.gateway_api_crds.manifests
  yaml_body         = each.value
  server_side_apply = true

  # Precisa do cluster acessivel e do acesso admin (access entry) para aplicar.
  depends_on = [
    aws_eks_node_group.node_group,
    aws_eks_access_policy_association.access_entry_association,
  ]
}

resource "kubectl_manifest" "aws_gateway_crds" {
  for_each          = data.kubectl_file_documents.aws_gateway_crds.manifests
  yaml_body         = each.value
  server_side_apply = true

  depends_on = [
    aws_eks_node_group.node_group,
    aws_eks_access_policy_association.access_entry_association,
  ]
}

# GatewayClass que liga o gatewayClassName "aws-lb-alb" (usado no chart da app)
# ao AWS Load Balancer Controller. Precisa ser criada manualmente - o LBC NAO a
# cria sozinho. Sem ela, o Gateway nunca fica Accepted/Programmed.
# Nome deve casar com var .Values.gateway.className do chart (aws-lb-alb).
resource "kubectl_manifest" "gateway_class" {
  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: GatewayClass
    metadata:
      name: aws-lb-alb
    spec:
      controllerName: gateway.k8s.aws/alb
  YAML

  # Precisa dos CRDs e do controller no ar para o GatewayClass ser aceito.
  depends_on = [
    kubectl_manifest.gateway_api_crds,
    helm_release.lb_controller,
  ]
}
