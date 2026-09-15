# Estado da infraestrutura armazenado no Terraform Cloud (HCP Terraform).
# A versao do Terraform e os providers ficam em versions.tf.
terraform {
  cloud {
    organization = "bgt3"

    workspaces {
      name = "wrench_auto_repair_email"
    }
  }
}
