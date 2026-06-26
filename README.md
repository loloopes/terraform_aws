# Terraform — AWS EKS for the Data Platform

Provisions **VPC**, **EKS**, **ECR**, **EBS storage class**, **metrics-server**, **AWS Load Balancer Controller + ACM TLS**, and optional **ingress-nginx** for running the stack in [`k8s/`](../k8s/).

## Architecture

```
bootstrap/ (one-time)  →  S3 + DynamoDB remote state

terraform apply
    ├── VPC (2 AZs, public + private subnets, NAT)
    ├── EKS cluster (managed node group)
    ├── ECR repositories (custom images)
    ├── aws-ebs-csi-driver + gp3 default StorageClass
    ├── metrics-server (HPA)
    ├── ACM certificate (*.base_domain) + Route53 validation (optional)
    └── AWS Load Balancer Controller (ALB Ingress, HTTPS)

push-images-ecr.sh  →  build + push to ECR
deploy-eks.sh       →  kustomize platform-eks-alb + apply
```

**Open-source stack deployed on the cluster** (unchanged from kind):

| Layer | Tools |
|-------|--------|
| Orchestration | Apache Airflow, Celery, Redis |
| ML | MLflow, LightGBM credit API |
| Lakehouse | MinIO, Hive Metastore, Trino, Spark, Iceberg |
| Vectors | pgvector |
| Streaming | Kafka |
| LLM | LangGraph, Trino MCP, LangSmith |
| Observability | Prometheus, Grafana, Alertmanager |

## Prerequisites

- AWS account with permissions for EKS, EC2, VPC, ECR, IAM, ACM, Route53
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- AWS credentials in `terraform/.env` (see below) or via `aws configure`
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker](https://docs.docker.com/get-docker/)
- A **domain** in Route53 (for ALB + ACM), or use nginx ingress fallback

## AWS authentication

Copy the example and add your keys:

```bash
cd terraform
cp .env.example .env
# Edit .env:
#   AWS_ACCESS_KEY_ID=...
#   AWS_SECRET_ACCESS_KEY=...
#   AWS_REGION=us-east-1
```

Verify before applying:

```bash
make verify-aws
```

All `make` targets load `.env` automatically via `scripts/with-env.sh`. Terraform does not read `.env` itself — the Makefile exports those variables to the AWS SDK.

**Alternative:** `aws configure` or `export AWS_PROFILE=...` (no `.env` needed).

## Quick start

### 0. Remote state (recommended)

```bash
cd terraform
make bootstrap-setup   # creates S3 + DynamoDB, writes backend.hcl, runs terraform init
make plan
```

Or step by step:

```bash
make bootstrap-init
make bootstrap
terraform -chdir=bootstrap output -raw backend_config > backend.hcl
make init
make plan
```

**Skip remote state** (local `terraform.tfstate` only):

```bash
make init-local
make plan
```

### 1. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit: region, base_domain, route53_zone_id, node sizes
make apply
```

**ALB + ACM (default):** set `base_domain` and `route53_zone_id` for automatic certificate validation.

**No domain (dev fallback):**

```hcl
enable_alb_ingress   = false
enable_ingress_nginx = true
```

### 2. Configure application secrets

```bash
cd ../k8s
cp .env.example .env
# Edit: HF_TOKEN, MLFLOW_MODEL_URI, passwords, etc.
```

### 3. Push images to ECR

```bash
bash scripts/push-images-ecr.sh
```

### 4. Deploy workloads

```bash
bash scripts/deploy-eks.sh
```

### 5. Access services

**ALB (HTTPS):**

```bash
# ALB hostname (after ingress provisions)
kubectl -n data-platform get ingress platform-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

terraform output platform_urls
```

Create a **wildcard DNS record** `*.example.com` → ALB hostname (Route53 alias or CNAME), then open:

| URL | Service |
|-----|---------|
| `https://credit.example.com` | Credit API |
| `https://mlflow.example.com` | MLflow |
| `https://airflow.example.com` | Airflow UI |
| `https://grafana.example.com` | Grafana |
| `https://trino.example.com` | Trino |
| `https://llm.example.com` | LLM API |
| `https://langgraph.example.com` | LangGraph |
| `https://minio.example.com` | MinIO console |

**nginx fallback (HTTP, `*.local`):**

```bash
kubectl -n ingress-nginx get svc ingress-nginx-controller
# Point /etc/hosts at LB for credit.local, mlflow.local, …
```

## Sizing notes

The full stack is **CPU-heavy** (credit-api ~1.5 CPU request, LLM pods, Airflow, Spark). For dev:

| Setting | Recommended |
|---------|-------------|
| `node_instance_types` | `["m5.xlarge"]` or `["m5.2xlarge"]` |
| `node_desired_size` | `3` |
| `node_min_size` | `2` |
| `node_max_size` | `6` |

## EKS vs kind differences

| kind | EKS |
|------|-----|
| `local/*` images loaded into kind | Images in **ECR** |
| NodePort on localhost | **ALB Ingress (HTTPS)** or nginx LB |
| `platform/` kustomize + NodePort patches | **`platform-eks-alb/`** or `platform-eks/` |
| metrics-server insecure TLS | metrics-server via Helm |
| default StorageClass | **gp3 EBS** via aws-ebs-csi-driver |

## Useful commands

```bash
# Terraform
cd terraform
make apply
make output
make kubeconfig
make destroy

# After code/image changes
cd k8s && make build
bash scripts/push-images-ecr.sh
bash scripts/deploy-eks.sh

# Status
kubectl -n data-platform get pods
kubectl -n data-platform get hpa
kubectl -n data-platform get ingress
```

## Production recommendations (not in this module)

- **RDS** instead of in-cluster Postgres (mlflow, airflow, mysql, pgvector)
- **S3** instead of MinIO for artifacts and lakehouse
- **Amazon MSK** instead of in-cluster Kafka
- **Secrets Manager** / External Secrets Operator instead of `secrets.env`
- **Cluster Autoscaler** or Karpenter
- **GPU node group** for LLM inference
- **ExternalDNS** for automatic Route53 records from Ingress

## Outputs

```bash
terraform output configure_kubectl
terraform output ecr_repository_urls
terraform output platform_urls
terraform output acm_certificate_arn
terraform output ingress_note
```

## Cost warning

EKS control plane (~$0.10/hr) + EC2 nodes + NAT gateway + ALB incur ongoing AWS charges. Use `terraform destroy` when not in use.
