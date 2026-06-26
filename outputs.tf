output "aws_region" {
  value = var.aws_region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_registry" {
  description = "ECR registry host (account.dkr.ecr.region.amazonaws.com)."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ecr_repository_urls" {
  description = "Map of image name to full ECR URL (without tag)."
  value = {
    for repo in local.ecr_repositories :
    repo => "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.cluster_name}/${repo}"
  }
}

output "ecr_login_command" {
  value = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ingress_type" {
  description = "Ingress controller in use: alb or nginx."
  value       = local.use_alb_ingress ? "alb" : "nginx"
}

output "base_domain" {
  description = "Base domain for HTTPS hostnames (empty when using nginx + *.local)."
  value       = var.base_domain
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN for ALB ingress (empty when using nginx)."
  value       = local.certificate_arn
}

output "ingress_hosts" {
  description = "HTTPS hostnames when using ALB ingress."
  value       = local.ingress_hosts
}

output "acm_validation_note" {
  description = "Steps to complete ACM validation when route53_zone_id is not set."
  value = local.use_alb_ingress && var.route53_zone_id == null && var.acm_certificate_arn == "" && var.base_domain != "" ? (
    "Add the CNAME records from: terraform output -json acm_domain_validation_options | jq"
  ) : "ACM validation handled via Route53 or existing certificate ARN."
}

output "acm_domain_validation_options" {
  value = length(module.acm) > 0 ? module.acm[0].domain_validation_options : []
}

output "ingress_note" {
  value = local.use_alb_ingress ? "After deploy-eks.sh: kubectl -n data-platform get ingress platform-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'" : (
    "kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
  )
}

output "platform_urls" {
  description = "Example HTTPS URLs after DNS points at the ALB."
  value = local.use_alb_ingress && var.base_domain != "" ? {
    credit    = "https://credit.${var.base_domain}"
    mlflow    = "https://mlflow.${var.base_domain}"
    airflow   = "https://airflow.${var.base_domain}"
    grafana   = "https://grafana.${var.base_domain}"
    trino     = "https://trino.${var.base_domain}"
    llm       = "https://llm.${var.base_domain}"
    langgraph = "https://langgraph.${var.base_domain}"
    minio     = "https://minio.${var.base_domain}"
  } : {}
}
