# State separado (apenas o DNS da aplicacao), em um workspace HCP proprio.
# A infra fica no workspace "wrench_auto_repair"; este cuida so do CNAME da app.
terraform {
  cloud {
    organization = "bgt3"

    workspaces {
      name = "wrench_auto_repair_dns"
    }
  }
}
