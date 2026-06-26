locals {
  cluster_name = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  ecr_repositories = [
    "mlflow",
    "credit-api",
    "hive-metastore",
    "spark-master",
    "spark-worker",
    "llm-trino-mcp",
    "llm-api",
    "llm-langgraph-api",
    "airflow",
  ]

  # ALB only when a domain or existing ACM cert is configured; otherwise nginx.
  use_alb_ingress   = var.enable_alb_ingress && (var.base_domain != "" || var.acm_certificate_arn != "")
  use_nginx_ingress = !local.use_alb_ingress

  ingress_hosts = var.base_domain != "" ? {
    credit    = "credit.${var.base_domain}"
    mlflow    = "mlflow.${var.base_domain}"
    llm       = "llm.${var.base_domain}"
    langgraph = "langgraph.${var.base_domain}"
    trino     = "trino.${var.base_domain}"
    minio     = "minio.${var.base_domain}"
    airflow   = "airflow.${var.base_domain}"
    grafana   = "grafana.${var.base_domain}"
  } : {}

  certificate_arn = var.acm_certificate_arn != "" ? var.acm_certificate_arn : (
    length(module.acm) > 0 ? module.acm[0].certificate_arn : ""
  )
}

module "vpc" {
  source = "./modules/vpc"

  name               = local.cluster_name
  azs                = slice(data.aws_availability_zones.available.names, 0, 2)
  single_nat_gateway = var.single_nat_gateway
  tags               = local.common_tags
}

module "ecr" {
  source = "./modules/ecr"

  repository_names = [for repo in local.ecr_repositories : "${local.cluster_name}/${repo}"]
  tags             = local.common_tags
}

module "eks" {
  source = "./modules/eks"

  cluster_name        = local.cluster_name
  cluster_version     = var.cluster_version
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_disk_size_gb   = var.node_disk_size_gb
  tags                = local.common_tags
}

module "acm" {
  count  = local.use_alb_ingress && var.acm_certificate_arn == "" && var.base_domain != "" ? 1 : 0
  source = "./modules/acm"

  domain_name     = var.base_domain
  route53_zone_id = var.route53_zone_id
  tags            = local.common_tags
}

module "alb_controller" {
  count  = local.use_alb_ingress ? 1 : 0
  source = "./modules/alb-controller"

  cluster_name      = module.eks.cluster_name
  aws_region        = var.aws_region
  vpc_id            = module.vpc.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  tags              = local.common_tags

  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}

resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"

  set = [{
    name  = "args[0]"
    value = "--kubelet-preferred-address-types=InternalIP"
  }]

  depends_on = [module.eks]
}

resource "helm_release" "ingress_nginx" {
  count = local.use_nginx_ingress ? 1 : 0

  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.0"

  set = [{
    name  = "controller.service.type"
    value = "LoadBalancer"
  }]

  depends_on = [module.eks]
}
