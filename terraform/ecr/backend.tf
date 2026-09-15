# Cria um container para subir as imagens da aplicação
terraform {
  cloud {
    organization = "bgt3"

    workspaces {
      name = "wrench_auto_repair_ecr"
    }
  }
}
