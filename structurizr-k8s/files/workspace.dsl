workspace "Wrench Auto Repair" "Modelo C4 da aplicação e da infraestrutura." {

    model {
        atendente = person "Atendente da Oficina" "Abre e acompanha ordens de serviço, veículos, clientes e peças."
        cliente   = person "Cliente" "Dono do veículo. Autentica-se com CPF, consulta as ordens de serviço vinculadas a ele, aprova ou recusa orçamentos e recebe as notificações por e-mail."

        wrench = softwareSystem "Wrench Auto Repair" "Gestão de ordens de serviço, veículos, clientes e controle de peças da oficina." {
            apiGateway = container "API Gateway" "Ponto de entrada público. Encaminha a autenticação por CPF para a Lambda e as rotas /api para a API após o authorizer." "AWS API Gateway HTTP API" {
                tags "Gateway"
            }
            lambdaAuth = container "Lambda de Autenticação" "Valida o CPF, consulta existência e status do cliente e emite o JWT." ".NET 10 / AWS Lambda" {
                tags "Serverless"
            }
            lambdaAuthorizer = container "Lambda Authorizer" "Valida assinatura, emissor, audiência e expiração do JWT nas rotas protegidas." ".NET 10 / AWS Lambda" {
                tags "Serverless"
            }
            api = container "API Wrench" "Expõe as APIs de OS (abertura, status, aprovação, listagem) e a atualização de status por e-mail." ".NET 10 / ASP.NET Core" {
                tags "API"

                web          = component "Sistema Web (API)" "Recebe as requisições HTTP, revalida o JWT e as encaminha para o Mediator." "ASP.NET Core"
                mediator     = component "Mediator" "Orquestra as requisições (padrão CQRS / Mediator)." ".NET 10"
                autenticacao = component "Autenticação" "Login por e-mail e senha, usuários, perfis e geração do token JWT." ".NET 10"
                cadastro     = component "Cadastro" "Fluxo para cadastro de clientes e veículos." ".NET 10"
                estoque      = component "Estoque" "Gestão de peças e insumos." ".NET 10"
                ordemServico = component "Ordem de Serviço" "Controle e acompanhamento da ordem de serviço." ".NET 10"
                dominio      = component "Domínio" "Regras de negócio." ".NET 10"
                emailService = component "Serviço de E-mail" "Adapta o envio de e-mail para o Amazon SES." ".NET 10 / AWS SDK"
                telemetria   = component "Telemetria" "Logs JSON com correlação, traces e métricas de negócio." "Serilog / OpenTelemetry"
            }
            database = container "Banco de Dados" "Armazena ordens de serviço, clientes, veículos, peças e usuários." "PostgreSQL 18" {
                tags "Database"
            }
        }

        cloudflare = softwareSystem "Cloudflare" "DNS público (bgt3.com.br) e validação de certificados." {
            tags "External"
        }
        ses = softwareSystem "Amazon SES" "Envio de e-mail transacional (atualização de status da OS)." {
            tags "External"
        }
        ecr = softwareSystem "Amazon ECR" "Registry das imagens Docker da API e do chart Helm." {
            tags "External"
        }
        newRelic = softwareSystem "New Relic" "APM, logs, métricas, dashboards, alertas e synthetic monitor." {
            tags "External"
        }
        cloudwatch = softwareSystem "Amazon CloudWatch Logs" "Logs estruturados das funções Lambda." {
            tags "External"
        }

        cliente -> apiGateway "Autentica com CPF e consome as APIs protegidas" "HTTPS / JSON"
        atendente -> apiGateway "Abre e consulta ordens de serviço" "HTTPS / JSON"
        apiGateway -> lambdaAuth "Encaminha POST /auth/cpf" "AWS_PROXY"
        apiGateway -> lambdaAuthorizer "Solicita a autorização das rotas /api" "Lambda REQUEST authorizer"
        apiGateway -> api "Encaminha requisições autorizadas" "HTTPS / HTTP_PROXY"
        apiGateway -> cloudflare "Resolve o hostname da API" "DNS"
        lambdaAuth -> database "Consulta cliente, usuário e perfil" "EF Core somente leitura, TCP 5432 (SSL)"
        lambdaAuth -> cloudwatch "Escreve logs JSON"
        lambdaAuthorizer -> cloudwatch "Escreve logs JSON"
        api -> database "Lê e grava dados" "EF Core, TCP 5432 (SSL)"
        api -> ses "Envia e-mail de atualização de status" "AWS SDK (IRSA)"
        api -> newRelic "Exporta traces, métricas e logs" "OTLP / HTTP"
        ses -> cliente "Entrega o e-mail de notificação da OS"
        ecr -> api "Fornece a imagem do container implantada" "OCI"

        apiGateway   -> web "Encaminha requisições autorizadas" "HTTPS / JSON"
        web          -> mediator "Requisição HTTP"
        mediator     -> autenticacao "Validar credenciais e fornecer token JWT"
        mediator     -> cadastro "Cadastro / Atualizações / Consultas"
        mediator     -> estoque "Cadastro / Atualizações / Consultas"
        mediator     -> ordemServico "Gestão da ordem de serviço"
        autenticacao -> dominio "Usa"
        cadastro     -> dominio "Usa"
        estoque      -> dominio "Usa"
        ordemServico -> dominio "Usa"
        dominio      -> database "Leitura e escrita" "EF Core"
        ordemServico -> emailService "Solicita o envio de e-mail"
        emailService -> ses "Envia e-mail" "AWS SES API"
        web          -> telemetria "Registra requisições com CorrelationId"
        ordemServico -> telemetria "Publica tempos por fase e falhas de processamento"
        telemetria   -> newRelic "Exporta telemetria" "OTLP / HTTP"

        production = deploymentEnvironment "Production" {

            cf = deploymentNode "Cloudflare" "Borda de DNS" "Cloudflare" {
                tags "External"
                cfDns = infrastructureNode "DNS bgt3.com.br" "CNAMEs: api -> ALB, prod-db -> RDS" "Cloudflare"
            }

            nr = deploymentNode "New Relic" "SaaS de observabilidade" "New Relic" {
                tags "External"
                nrIngest    = infrastructureNode "Ingest OTLP e Infrastructure" "Recebe traces, métricas e logs; alimenta dashboards e alert policies" "New Relic"
                nrSynthetic = infrastructureNode "Synthetic Monitor" "Verifica /health periodicamente para uptime" "New Relic"
            }

            aws = deploymentNode "Amazon Web Services" "Conta AWS - região us-east-1" "AWS" {
                tags "Amazon Web Services - Cloud"

                ecrNode = infrastructureNode "Amazon ECR" "Imagens Docker + chart Helm" "AWS"
                sesNode = infrastructureNode "Amazon SES" "Domínio verificado + DKIM" "AWS"
                acmNode = infrastructureNode "AWS Certificate Manager" "Certificado TLS da aplicação (HTTPS)" "AWS"
                cwNode  = infrastructureNode "Amazon CloudWatch Logs" "Logs JSON das funções Lambda" "AWS"

                apiGw = deploymentNode "Amazon API Gateway" "HTTP API wrench-api-gateway-production" "AWS API Gateway" {
                    tags "Amazon Web Services - API Gateway"
                    apiGatewayInstance = containerInstance apiGateway
                }

                lambdas = deploymentNode "AWS Lambda" "Runtime .NET 10, logs em JSON" "AWS Lambda" {
                    tags "Amazon Web Services - Lambda"
                    lambdaAuthInstance       = containerInstance lambdaAuth
                    lambdaAuthorizerInstance = containerInstance lambdaAuthorizer
                }

                vpc = deploymentNode "VPC 10.0.0.0/16" "Rede isolada" "AWS VPC" {

                    publicSubnets = deploymentNode "Subnets públicas (x3)" "Uma por AZ" "AWS" {
                        alb = infrastructureNode "Application Load Balancer" "internet-facing; criado pelo AWS Load Balancer Controller a partir do Gateway (Gateway API)" "Elastic Load Balancing"
                    }

                    privateSubnets = deploymentNode "Subnets privadas (x3)" "Uma por AZ; saída via NAT Gateway" "AWS" {

                        eks = deploymentNode "Amazon EKS" "Cluster eks-wrench-auto-repair" "Elastic Kubernetes Service" {

                            nodegroup = deploymentNode "Node group" "2x t3.medium (autoscale 1-3), disco 50 GB" "Amazon EC2" {

                                prod = deploymentNode "Namespace: production" "" "Kubernetes" {
                                    apiInstance = containerInstance api "" "Deployment + HPA (CPU 50%, 1-6 réplicas); Service ClusterIP; exposto via Gateway/HTTPRoute; ServiceAccount com IRSA"
                                }

                                kubesystem = deploymentNode "Namespace: kube-system" "Controllers de cluster" "Kubernetes" {
                                    lbc = infrastructureNode "AWS Load Balancer Controller" "Cria e gerencia o ALB (Gateway API)" "Kubernetes"
                                    ebs = infrastructureNode "EBS CSI Driver" "Provisiona volumes EBS" "Kubernetes"
                                    ms  = infrastructureNode "Metrics Server" "Métricas de CPU para o HPA" "Kubernetes"
                                }

                                newrelicNs = deploymentNode "Namespace: newrelic" "Integração Kubernetes do New Relic" "Kubernetes" {
                                    nriBundle = infrastructureNode "nri-bundle" "Infrastructure agent (DaemonSet), kube-state-metrics, eventos e Fluent Bit" "Helm"
                                }
                            }
                        }
                    }
                }

                rds = deploymentNode "Amazon RDS" "PostgreSQL 18 - db.t4g.micro (publicly accessible, backup 7 dias)" "Amazon RDS" {
                    dbInstance = containerInstance database
                }
            }

            apiGatewayInstance -> cfDns "Resolve o hostname da API" "DNS"
            cfDns -> alb "Resolve para (CNAME)"
            alb -> apiInstance "Encaminha requisições; termina TLS com o cert ACM" "HTTPS"
            acmNode -> alb "Fornece o certificado (descoberto por hostname)"
            lbc -> alb "Provisiona / configura"
            ms -> apiInstance "Alimenta o autoscaling (HPA)"
            apiInstance -> sesNode "Envia e-mail via IRSA" "AWS SDK"
            ecrNode -> apiInstance "Imagem do container" "OCI pull"
            apiInstance -> nrIngest "Exporta traces, métricas e logs" "OTLP / HTTP"
            nriBundle -> apiInstance "Coleta CPU, memória e stdout dos pods"
            nriBundle -> nrIngest "Envia métricas, eventos e logs do cluster"
            nrSynthetic -> cfDns "Consulta GET /health"
            lambdaAuthInstance -> cwNode "Escreve logs JSON"
            lambdaAuthorizerInstance -> cwNode "Escreve logs JSON"
        }
    }

    views {
        systemContext wrench "Contexto" "Visão de contexto do sistema Wrench Auto Repair." {
            include *
            autolayout lr
        }

        container wrench "Containers" "Borda autenticada, API e banco de dados do sistema." {
            include *
            autolayout lr
        }

        component api "Componentes" "Componentes internos da API Wrench." {
            include *
            autolayout tb
        }

        dynamic wrench "Autenticacao" "Autenticação por CPF e consumo de rota protegida." {
            cliente -> apiGateway "POST /auth/cpf com o CPF"
            apiGateway -> lambdaAuth "Encaminha a requisição"
            lambdaAuth -> database "Consulta cliente, usuário e perfil"
            cliente -> apiGateway "Chama /api com Bearer JWT"
            apiGateway -> lambdaAuthorizer "Valida o token"
            apiGateway -> api "Encaminha a requisição autorizada"
            api -> database "Lê e grava dados"
            autolayout lr
        }

        deployment wrench production "Deployment" "Infraestrutura de produção na AWS com borda autenticada, EKS, RDS e New Relic." {
            include *
            autolayout lr
        }

        themes https://static.structurizr.com/themes/amazon-web-services-2023.01.31/theme.json

        styles {
            element "Person" {
                shape person
                background #6E0F10
                color #ffffff
            }
            element "Software System" {
                background #A11517
                color #ffffff
            }
            element "External" {
                background #8A8A8A
                color #ffffff
            }
            element "Container" {
                background #B23A3B
                color #ffffff
            }
            element "Component" {
                background #C46A6B
                color #ffffff
            }
            element "API" {
                shape roundedbox
            }
            element "Gateway" {
                shape pipe
            }
            element "Serverless" {
                shape hexagon
            }
            element "Database" {
                shape cylinder
            }
            element "Infrastructure Node" {
                background #eeeeee
                color #000000
            }
        }
    }
}
