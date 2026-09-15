# New Relic Kubernetes integration (`nri-bundle`)

Values do chart oficial [`newrelic/nri-bundle`](https://github.com/newrelic/helm-charts/tree/master/charts/nri-bundle),
que instala no cluster EKS o agente de infraestrutura do New Relic. É ele que reporta CPU e
memória de nós e pods, estado dos objetos do Kubernetes, eventos do cluster e logs do `stdout` dos
containers. A telemetria da própria API (traces, métricas e logs via OTLP) é configurada no
repositório `app-k8s` e não depende deste agente.

## O que o `values.yaml` habilita

| Chave | Componente | Para quê |
|---|---|---|
| `global.cluster` | — | Nome do cluster em `clusterName`. O pipeline sobrescreve com o output `cluster_name` do stack `terraform/infra`; os dashboards e alertas filtram por esse valor |
| `global.lowDataMode` | — | Reduz a frequência de coleta e o volume ingerido, mantendo o uso dentro do free tier |
| `newrelic-infrastructure` | DaemonSet, um pod por nó, privilegiado | CPU e memória por nó, pod e container (`K8sNodeSample`, `K8sPodSample`, `K8sContainerSample`) |
| `kube-state-metrics` | Deployment | Estado de deployments, pods e HPA; alimenta restarts e réplicas |
| `nri-kube-events` | Deployment | Eventos do cluster, como reinício de pod e falha de scheduling |
| `newrelic-logging` | DaemonSet Fluent Bit | Logs do `stdout` de todos os containers, inclusive os que não exportam OTLP |

A license key **não** fica neste arquivo. Ela é injetada na instalação por
`--set global.licenseKey`, a partir do secret `NEW_RELIC_LICENSE_KEY`.

## Instalação automática

O workflow [`.github/workflows/newrelic.yml`](../.github/workflows/newrelic.yml) roda a cada push em
`master`, depois do stack `infra`, chamado pelo `ci-cd.yml`:

```bash
helm upgrade --install newrelic-bundle newrelic/nri-bundle \
  -n newrelic --create-namespace \
  -f newrelic-k8s/values.yaml \
  --set global.cluster="$CLUSTER_NAME" \
  --set global.licenseKey="$NEW_RELIC_LICENSE_KEY" \
  --wait --timeout 10m
```

O comando é idempotente: alterar este `values.yaml` e fazer merge em `master` atualiza o agente.

| Nome | Tipo | Descrição |
|---|---|---|
| `NEW_RELIC_LICENSE_KEY` | secret | Ingest - License Key da conta (campo **Value**, não o Key ID) |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | secret | Credenciais com acesso ao cluster EKS |
| `AWS_REGION` | variable | Região do cluster |

## Instalação manual

Alternativa para diagnóstico ou para um cluster fora do pipeline. Requer `kubectl`, `helm` e acesso
ao cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name eks-wrench-auto-repair

helm repo add newrelic https://helm-charts.newrelic.com
helm repo update

export NEW_RELIC_LICENSE_KEY="<license key, somente na sessão do terminal>"

helm upgrade --install newrelic-bundle newrelic/nri-bundle \
  -n newrelic --create-namespace \
  -f newrelic-k8s/values.yaml \
  --set global.licenseKey="$NEW_RELIC_LICENSE_KEY"
```

## Validar

```bash
kubectl -n newrelic get daemonset
kubectl -n newrelic get pods
```

Os DaemonSets precisam ter um pod `Running` por nó. Em `one.newrelic.com` → **Infrastructure →
Kubernetes**, o cluster `eks-wrench-auto-repair` aparece com nós e pods reportando em poucos
minutos.

## Desinstalar

```bash
helm uninstall newrelic-bundle -n newrelic
```
