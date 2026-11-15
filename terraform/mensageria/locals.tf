data "aws_caller_identity" "atual" {}

data "terraform_remote_state" "infra" {
  backend = "remote"

  config = {
    organization = var.tfc_organization
    workspaces = {
      name = var.infra_workspace
    }
  }
}

locals {
  oidc_provider_arn  = data.terraform_remote_state.infra.outputs.oidc_provider_arn
  oidc_provider_host = data.terraform_remote_state.infra.outputs.oidc_provider_host

  conta  = data.aws_caller_identity.atual.account_id
  regiao = var.region_default

  # Um topico por publicador: cada servico so publica no seu proprio topico.
  topicos = {
    os       = "${var.prefixo}-os-events"
    billing  = "${var.prefixo}-billing-events"
    execucao = "${var.prefixo}-execucao-events"
  }

  # Uma fila (com DLQ) por consumidor. O filtro seleciona, no topico de origem,
  # apenas as mensagens que aquele consumidor sabe tratar.
  filas = {
    billing_orcamento = {
      nome   = "${var.prefixo}-billing-gerar-orcamento"
      topico = "os"
      tipos  = ["GerarOrcamento"]
    }
    billing_cancelamento = {
      nome   = "${var.prefixo}-billing-cancelar-orcamento"
      topico = "os"
      tipos  = ["CancelarOrcamento"]
    }
    billing_estorno = {
      nome   = "${var.prefixo}-billing-estornar-pagamento"
      topico = "os"
      tipos  = ["EstornarPagamento"]
    }
    execucao = {
      nome   = "${var.prefixo}-execucao-commands"
      topico = "os"
      tipos  = ["IniciarExecucao", "CancelarExecucao"]
    }
    os_billing = {
      nome   = "${var.prefixo}-os-saga"
      topico = "billing"
      tipos  = ["OrcamentoCriado", "OrcamentoFalhou", "OrcamentoAprovado", "OrcamentoRecusado", "PagamentoAprovado", "PagamentoFalhou", "PagamentoEstornado", "EstornoFalhou"]
    }
    os_execucao = {
      nome   = "${var.prefixo}-os-saga"
      topico = "execucao"
      tipos  = ["ExecucaoConcluida", "ExecucaoFalhou"]
    }
  }

  # Nomes distintos das filas: os_billing e os_execucao compartilham a fila do OS Service,
  # que recebe de dois topicos.
  nomes_filas = toset([for fila in local.filas : fila.nome])

  tabelas_dynamodb = "arn:aws:dynamodb:${local.regiao}:${local.conta}:table/${var.dynamodb_table_prefix}"

  # Uma role IRSA por servico, assumida pela ServiceAccount informada em cada chart Helm.
  servicos = {
    os = {
      service_account = "wrench-api-sa"
      publica         = ["os"]
      consome         = ["${var.prefixo}-os-saga"]
    }
    billing = {
      service_account = "wrench-billing-sa"
      publica         = ["billing"]
      consome = [
        "${var.prefixo}-billing-gerar-orcamento",
        "${var.prefixo}-billing-cancelar-orcamento",
        "${var.prefixo}-billing-estornar-pagamento"
      ]
    }
    execucao = {
      service_account = "wrench-execucao-sa"
      publica         = ["execucao"]
      consome         = ["${var.prefixo}-execucao-commands"]
    }
  }
}
