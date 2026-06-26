variable "aws_region" {
  description = "AWS region for EKS and ECR."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for cluster, ECR repos, and tags."
  type        = string
  default     = "data-platform"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.31"
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["m5.xlarge"]
}

variable "node_desired_size" {
  description = "Desired worker nodes."
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Minimum worker nodes."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum worker nodes."
  type        = number
  default     = 6
}

variable "node_disk_size_gb" {
  description = "Root EBS volume size (GiB) per node."
  type        = number
  default     = 100
}

variable "enable_ingress_nginx" {
  description = "Install ingress-nginx via Helm. Use when enable_alb_ingress is false."
  type        = bool
  default     = false
}

variable "enable_metrics_server" {
  description = "Install metrics-server (required for HPA)."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway to reduce cost in dev."
  type        = bool
  default     = true
}

variable "enable_alb_ingress" {
  description = "Install AWS Load Balancer Controller and provision ACM TLS for ALB ingress."
  type        = bool
  default     = true
}

variable "base_domain" {
  description = "Base domain for HTTPS ingress (e.g. example.com → credit.example.com). Required when enable_alb_ingress is true unless acm_certificate_arn is set."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for automatic ACM DNS validation and optional wildcard alias records."
  type        = string
  default     = null
}

variable "acm_certificate_arn" {
  description = "Existing ACM certificate ARN (must cover base_domain and *.base_domain). Skips ACM creation when set."
  type        = string
  default     = ""
}

