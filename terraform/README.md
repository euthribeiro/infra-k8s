# Terraform — Infraestrutura como Código (IaC)

Infraestrutura Kubernetes do **Tech Challenge — Fase 3** (aplicação _Wrench Auto Repair_) na
AWS, provisionada com Terraform e estado remoto no **HCP Terraform (Terraform Cloud)**,
organização `bgt3`.

A infraestrutura está dividida em **seis _root modules_ independentes**, cada um com o seu
próprio _state_ (workspace HCP). A separação existe para isolar ciclos de vida diferentes (uma
stack pode ser aplicada/destruída sem tocar nas outras) e para resolver dependências de ordem —
por exemplo, o CNAME da aplicação só pode ser criado depois que o Load Balancer da aplicação
existe.

```
terraform/
├── infra/        # VPC, EKS, node group, IAM/IRSA, EBS CSI, Metrics Server,
│                 # AWS Load Balancer Controller, CRDs da Gateway API, ACM
│                 # workspace HCP: wrench_auto_repair
├── ecr/          # Repositórios ECR (imagem da API + charts Helm)
│                 # workspace HCP: wrench_auto_repair_ecr
├── email/        # Amazon SES (domínio + DKIM) e role IRSA de envio de e-mail
│                 # workspace HCP: wrench_auto_repair_email
├── dns/          # CNAME público da aplicação (-> ALB do Gateway)
│                 # workspace HCP: wrench_auto_repair_dns
├── structurizr/  # Cloudflare Tunnel que expõe o Structurizr Lite
│                 # workspace HCP: wrench_auto_repair_structurizr
└── observability/ # New Relic: dashboard, alertas, notificação e synthetic monitor
                   # workspace HCP: wrench_auto_repair_observability
```

> **O banco de dados não está aqui.** A instância RDS, o DB subnet group, o security group do
> Postgres e o CNAME `prod-db` vivem no repositório **`infra-db`** desde a Fase 3. Este
> repositório apenas publica `vpc_id` e `public_subnet_ids` para que o `infra-db` posicione
> aqueles recursos dentro desta VPC.

> **Versões:** Terraform `>= 1.5.0`. Providers: `hashicorp/aws ~> 6.0`,
> `cloudflare/cloudflare ~> 5.0`, `hashicorp/helm ~> 2.17`, `hashicorp/tls ~> 4.0`,
> `gavinbunney/kubectl ~> 1.19`, `hashicorp/http ~> 3.4` e `newrelic/newrelic ~> 3.0`.

---

## 1. Stack `infra/` — rede, cluster e pré-requisitos

Workspace HCP: **`wrench_auto_repair`**. É a base de tudo; as demais stacks — e os repositórios
`infra-db` e `app-k8s` — leem os _outputs_ dela via `terraform_remote_state`.

### Recursos criados

| Grupo           | Recurso Terraform                                             | O que é / para quê                                                           |
| --------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| **Rede**        | `aws_vpc.vpc_wrench`                                          | VPC `10.0.0.0/16` com DNS habilitado                                         |
|                 | `aws_subnet.public_subnet` (x3)                               | Subnets públicas (recebem os ALBs internet-facing)                           |
|                 | `aws_subnet.private_subnet` (x3)                              | Subnets privadas (cluster e nós EKS)                                         |
|                 | `aws_internet_gateway.igw`                                    | Saída pública da VPC                                                         |
|                 | `aws_eip.nat` + `aws_nat_gateway.nat`                         | Saída para internet dos nós privados                                         |
|                 | `aws_route_table.rt_public/rt_private` + associações          | Rotas público (IGW) e privado (NAT)                                          |
|                 | `aws_security_group.sg`                                       | SG do cluster (libera 80/443 de entrada)                                     |
| **EKS**         | `aws_eks_cluster.cluster`                                     | Cluster `eks-wrench-auto-repair` (authentication_mode `API`)                 |
|                 | `aws_eks_node_group.node_group`                               | Node group `t3.medium`, discos 50 GB, escala 1–3 (desejado 2)                |
|                 | `aws_eks_access_entry` + `aws_eks_access_policy_association`  | Acesso admin do usuário IAM ao cluster                                       |
| **IAM**         | `aws_iam_role.cluster` (+ attach `AmazonEKSClusterPolicy`)    | Role do control plane                                                        |
|                 | `aws_iam_role.node_group_role` (+ 3 attachments)              | Role dos nós (Worker, CNI, ECR read-only)                                    |
| **IRSA**        | `aws_iam_openid_connect_provider.oidc`                        | Provider OIDC do cluster (base de todo IRSA)                                 |
|                 | `aws_iam_role.ebs_csi` (+ policy `AmazonEBSCSIDriverPolicy`)  | Role IRSA do EBS CSI Driver                                                  |
|                 | `aws_iam_policy.lb_controller` + `aws_iam_role.lb_controller` | Policy oficial + role IRSA do AWS Load Balancer Controller                   |
| **Addons**      | `aws_eks_addon.metrics_server`                                | Metrics Server — alimenta o **HPA** e o `kubectl top`                        |
|                 | `aws_eks_addon.ebs_csi`                                       | EBS CSI Driver (provisiona volumes/PVC)                                      |
|                 | `helm_release.lb_controller`                                  | AWS Load Balancer Controller (chart `3.4.0`, cria o ALB a partir do Gateway) |
| **Gateway API** | `kubectl_manifest.gateway_api_crds`                           | CRDs padrão da Gateway API (`standard-install` v1.5.0)                       |
|                 | `kubectl_manifest.aws_gateway_crds`                           | CRDs _vended_ da AWS (TargetGroupConfiguration, LoadBalancerConfiguration…)  |
|                 | `kubectl_manifest.gateway_class`                              | `GatewayClass` `aws-lb-alb` → controller `gateway.k8s.aws/alb`               |
| **HTTPS**       | `aws_acm_certificate.app`                                     | Certificado ACM (default `api.bgt3.com.br`)                                  |
|                 | `cloudflare_dns_record.acm_validation`                        | Registros CNAME de validação do ACM no Cloudflare                            |
|                 | `aws_acm_certificate_validation.app`                          | Espera o ACM ficar validado                                                  |

### Outputs relevantes

`cluster_name`, `cluster_endpoint`, `region`, `vpc_id`, `public_subnet_ids`,
`cluster_oidc_issuer`, `acm_certificate_arn`, `lb_controller_role_arn`, `app_hostnames`,
`oidc_provider_arn`, `oidc_provider_host`.

Quem consome o quê:

| Output | Consumidor |
| ------ | ---------- |
| `vpc_id`, `public_subnet_ids` | `infra-db`, stack `rds/` |
| `cluster_name` | `app-k8s`, job de deploy; job `gateway` deste repositório |
| `acm_certificate_arn` | job `gateway` deste repositório (listener HTTPS do Gateway de plataforma) |
| `oidc_provider_arn`, `oidc_provider_host` | stack `email/` |
| `app_hostnames` | stack `dns/` |

### Como aplicar

```bash
terraform -chdir=terraform/infra init -upgrade
terraform -chdir=terraform/infra apply
```

> `init -upgrade` é necessário na primeira vez (providers `helm`/`tls`/`kubectl`/`http`).

**Variáveis sensíveis** (definir como _Terraform Variables_ no workspace HCP ou via
`TF_VAR_...`): `cloudflare_api_token`, `cloudflare_zone_id`.

---

## 2. Stack `ecr/` — repositórios de container e chart

Workspace HCP: **`wrench_auto_repair_ecr`**. Cria os repositórios onde o CI publica a imagem
Docker da API e os pacotes dos charts Helm.

### Recursos criados

| Recurso                                               | O que faz                                               |
| ----------------------------------------------------- | ------------------------------------------------------- |
| `aws_ecr_repository.wrench_repo["api"]`               | Repositório `wrench/api` (imagem da aplicação)          |
| `aws_ecr_repository.wrench_repo["charts/wrench-api"]` | Repositório OCI `wrench/charts/wrench-api` (chart Helm) |
| `aws_ecr_repository.wrench_repo["charts/structurizr"]`| Repositório OCI do chart do Structurizr                 |

Todos com `scan_on_push` habilitado, criptografia `AES256` e imutabilidade de tag (com exceções
para `latest*`, `alpine*`, `dev-*`).

Outputs: `api_repository_url`, `chart_repository`, `chart_repository_url`,
`structurizr_chart_repository`, `structurizr_chart_repository_url`.

### Como aplicar

```bash
terraform -chdir=terraform/ecr init
terraform -chdir=terraform/ecr apply \
  -var="region_default=us-east-1" \
  -var='main_tags={Terraform="true", Environment="production"}'
```

---

## 3. Stack `email/` — Amazon SES + IRSA

Workspace HCP: **`wrench_auto_repair_email`**. Provisiona o envio de e-mail transacional
(atualização de status da ordem de serviço) via Amazon SES.

### Recursos criados

| Recurso                                                | O que faz                                                                                        |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| `aws_ses_configuration_set.config_set`                 | Configuration set `wrench-email` (TLS obrigatório no envio)                                      |
| `aws_ses_domain_identity.domain_identity`              | Identidade do domínio `bgt3.com.br` no SES                                                       |
| `aws_ses_domain_dkim.dkim_identity`                    | Habilita Easy DKIM (gera 3 tokens)                                                               |
| `cloudflare_dns_record.ses_verification`               | TXT `_amazonses.<domínio>` (posse do domínio)                                                    |
| `cloudflare_dns_record.dkim` (x3)                      | 3 CNAMEs de DKIM (assinatura das mensagens)                                                      |
| `aws_ses_domain_identity_verification`                 | Espera o SES confirmar a verificação                                                             |
| `aws_ses_email_identity.allowed`                       | Identidades de e-mail autorizadas (sandbox do SES)                                               |
| `aws_iam_role.app_ses_irsa` (+ policy `ses:SendEmail`) | **Role IRSA** que a ServiceAccount da app assume para enviar (`create_irsa_role = true`, padrão) |
| `aws_iam_user.app_ses` + access key                    | Alternativa por chave estática (`create_smtp_user = true`, desligado por padrão)                 |

A trust policy da role IRSA libera a ServiceAccount `wrench-api-sa` nos namespaces de
`k8s_namespaces` (padrão `production` e `homologacao`) — os valores precisam casar com o chart
Helm do `app-k8s`. O OIDC provider é lido do state da `infra/`.

Output principal: `app_ses_irsa_role_arn` (injetado no chart via
`--set serviceAccount.roleArn=...`).

### Como aplicar

```bash
terraform -chdir=terraform/email init
terraform -chdir=terraform/email apply
```

> Variáveis sensíveis: `cloudflare_api_token`, `cloudflare_zone_id`. Ver
> `email/terraform.tfvars.example`.

---

## 4. Stack `dns/` — CNAME público da aplicação

Workspace HCP: **`wrench_auto_repair_dns`**. Cria o registro DNS público que aponta o hostname da
aplicação para o ALB provisionado pelo Load Balancer Controller.

### Recursos criados

| Recurso                     | O que faz                                                           |
| --------------------------- | ------------------------------------------------------------------- |
| `data.aws_lb.gateway`       | Descobre o ALB do Gateway pela tag `elbv2.k8s.aws/cluster`          |
| `cloudflare_dns_record.app` | CNAME (`api.bgt3.com.br` e `hml-api.bgt3.com.br` → DNS do ALB), um por hostname não-curinga |

### Por que um state separado

O CNAME depende do ALB, que só existe **depois** que o Gateway de plataforma é aplicado no cluster
(o Load Balancer Controller cria o ALB ao ver o `Gateway`). O Gateway é aplicado por `kubectl`, fora
do Terraform, depois da `infra/`; por isso o DNS não pode estar no mesmo state. Com o state
isolado, a `infra/` nunca toca no CNAME e o `dns/` é idempotente: cria na primeira vez e é _no-op_
depois.

### Como aplicar

```bash
terraform -chdir=terraform/dns init
terraform -chdir=terraform/dns apply
```

> Só deve rodar **depois** que o Gateway já tem endereço (ALB pronto). No pipeline deste
> repositório isso é garantido pelo job `gateway`, que executa
> `kubectl wait --for=condition=Programmed gateway/bgt3-gw -n gateway` antes do job `dns`.

---

## 5. Stack `structurizr/` — túnel do Structurizr

Workspace HCP: **`wrench_auto_repair_structurizr`**. Provisiona o Cloudflare Tunnel que expõe o
Structurizr Lite rodando no cluster, sem abrir um segundo ALB.

O chart que implanta o Structurizr está em `structurizr-k8s/`; os manifestos brutos equivalentes,
mantidos como referência de leitura, em `kubernetes/structurizr/`.

### Como aplicar

```bash
terraform -chdir=terraform/structurizr init
terraform -chdir=terraform/structurizr apply
```

---

## 6. Stack `observability/` — New Relic como código

Workspace HCP: **`wrench_auto_repair_observability`**. Não cria recurso na AWS: provisiona, na
conta New Relic, tudo o que consome a telemetria enviada pela aplicação (OTLP) e pelo `nri-bundle`.

### Recursos criados

| Recurso | O que faz |
| ------- | --------- |
| `newrelic_one_dashboard.wrench` | Dashboard `Wrench Auto Repair` com as páginas Negócio, API, Integrações, Kubernetes e Healthcheck |
| `newrelic_alert_policy.wrench` | Política `Wrench Auto Repair`, uma issue por condição |
| `newrelic_nrql_alert_condition.falha_processamento_ordem_servico` | Qualquer incremento de `ordemservico.processamento.falhas` em 5 minutos |
| `newrelic_nrql_alert_condition.taxa_erro_5xx_api` | Percentual de respostas 5xx acima de `taxa_erro_5xx_limite_percentual` por 5 minutos |
| `newrelic_nrql_alert_condition.latencia_p95_api` | Latência p95 acima de `latencia_p95_limite_ms` por 5 minutos |
| `newrelic_nrql_alert_condition.restart_pods_api` | Qualquer restart de container da API |
| `newrelic_nrql_alert_condition.healthcheck_indisponivel` | Synthetic com falha em duas execuções seguidas |
| `newrelic_notification_destination.email` + `newrelic_notification_channel.email` | Destino e canal de e-mail |
| `newrelic_workflow.wrench` | Encaminha as issues da política para o canal de e-mail |
| `newrelic_synthetics_monitor.healthcheck` | `GET` em `app_health_url` a cada 5 minutos, exigindo `Healthy` na resposta |

### Variáveis

| Variável | Obrigatória | Default | Descrição |
| -------- | ----------- | ------- | --------- |
| `newrelic_account_id` | sim | — | ID da conta |
| `newrelic_api_key` | sim (sensível) | — | User API Key `NRAK-...` |
| `alert_email` | sim | — | Destinatário das notificações |
| `newrelic_region` | não | `US` | `US` ou `EU` |
| `service_name` | não | `wrench-auto-repair-api` | Precisa casar com `Observability:ServiceName` da API |
| `cluster_name` | não | `eks-wrench-auto-repair` | Precisa casar com `global.cluster` do `nri-bundle` |
| `app_health_url` | não | `https://api.bgt3.com.br/health` | URL verificada pelo synthetic |
| `api_pod_prefix` | não | `wrench-api` | Prefixo dos pods da API |
| `synthetic_locations` | não | `["US_EAST_1", "SA_EAST_1"]` | Localizações públicas do synthetic |
| `latencia_p95_limite_ms` | não | `1500` | Limite do alerta de latência |
| `taxa_erro_5xx_limite_percentual` | não | `5` | Limite do alerta de erro 5xx |

Output: `dashboard_permalink`, `alert_policy_id`, `synthetic_monitor_id`.

### Como aplicar

```bash
terraform -chdir=terraform/observability init
terraform -chdir=terraform/observability apply \
  -var="newrelic_account_id=<id>" \
  -var="newrelic_api_key=<NRAK-...>" \
  -var="alert_email=<e-mail>"
```

No pipeline, os valores vêm dos secrets `NEW_RELIC_ACCOUNT_ID` e `NEW_RELIC_API_KEY` e da variável
`NEW_RELIC_ALERT_EMAIL` (workflow `observability.yml`). O significado de cada painel e as consultas
NRQL estão no repositório `app-k8s`, em `docs/observability/dashboards-nrql.md`.

### Agente do cluster

O `nri-bundle` não é um stack Terraform: é instalado por Helm pelo workflow `newrelic.yml`, logo
depois do `infra/`, com os values de [`newrelic-k8s/`](../newrelic-k8s/README.md).

---

## Ordem de aplicação (visão geral)

Ponta a ponta, atravessando os quatro repositórios:

```
1. infra-k8s  terraform/infra         # VPC, EKS, controllers, ACM
2. infra-k8s  kubernetes/gateway      # Gateway de plataforma -> ALB único
3. infra-k8s  terraform/dns           # CNAMEs api e hml-api -> ALB
4. infra-k8s  terraform/ecr, email    # paralelizáveis após a infra
   infra-k8s  Helm (nri-bundle)       # agente New Relic no cluster
   infra-k8s  terraform/observability # dashboard, alertas e synthetic; independe da AWS
5. infra-db   terraform/rds           # instância RDS
6. infra-db   terraform/roles         # roles e database de homologação
7. app-k8s    Helm (wrench-api-k8s)   # homologação e produção: HTTPRoutes no Gateway
8. infra-db   terraform/roles         # grants de coluna da Lambda por ambiente
9. lambda-auth                        # Lambdas e API Gateway por ambiente
```

Cada repositório aplica a sua parte no próprio GitHub Actions, e os valores atravessam a fronteira
por remote state. O workflow **Orquestrador de Provisionamento** do `infra-k8s` executa a
sequência inteira disparando o pipeline de cada repositório; o **Orquestrador de Destruição**
percorre o caminho inverso. Ambos estão descritos no [README do repositório](../README.md).

## Pré-requisitos de HCP Terraform

- Criar os workspaces listados acima, cada um com o _working directory_ apontando para a
  respectiva pasta (`terraform/infra`, `terraform/ecr`, etc.).
- Habilitar **state sharing** do workspace da infra (`wrench_auto_repair`) para os workspaces de
  `email`, `dns`, `structurizr`, para o `wrench_auto_repair_rds` (repositório `infra-db`) e para o
  leitor de outputs do `app-k8s`. Todos consomem `terraform_remote_state`.
- Definir as variáveis sensíveis (Cloudflare) como _Terraform Variables_ marcadas como
  _sensitive_ nos workspaces, nunca commitadas.

## Observação sobre HTTPS (ACM + Gateway)

O HTTPS termina no ALB com o certificado do ACM, informado como `defaultCertificate` da
`LoadBalancerConfiguration` `bgt3-gw-lbconfig` do Gateway de plataforma (não usa
`certificateRefs`). O certificado é um só para todos os hostnames atendidos pelo ALB, então
`var.acm_domains` (stack `infra/`) precisa conter todos os hostnames das `HTTPRoute` publicadas
pelo `app-k8s` — hoje `api.bgt3.com.br` e `hml-api.bgt3.com.br`.
