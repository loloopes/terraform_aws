variable "domain_name" {
  description = "Base domain for the platform (e.g. example.com). Hosts become credit.example.com, mlflow.example.com, etc."
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for automatic ACM DNS validation. Leave null to create the cert and validate manually."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_acm_certificate" "platform" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_route53_record" "validation" {
  for_each = var.route53_zone_id != null ? {
    for dvo in aws_acm_certificate.platform.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id         = var.route53_zone_id
  name            = each.value.name
  records         = [each.value.record]
  type            = each.value.type
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "platform" {
  count = var.route53_zone_id != null ? 1 : 0

  certificate_arn         = aws_acm_certificate.platform.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

output "certificate_arn" {
  description = "ACM certificate ARN for the ALB ingress."
  value       = var.route53_zone_id != null ? aws_acm_certificate_validation.platform[0].certificate_arn : aws_acm_certificate.platform.arn
}

output "domain_validation_options" {
  description = "DNS records to create when route53_zone_id is not set."
  value       = aws_acm_certificate.platform.domain_validation_options
}

output "certificate_status" {
  value = aws_acm_certificate.platform.status
}
