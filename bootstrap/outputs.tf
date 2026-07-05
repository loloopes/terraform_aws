output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}

output "aws_region" {
  value = var.aws_region
}

output "backend_config" {
  description = "Copy these values into terraform/backend.hcl"
  value       = <<-EOT
    bucket         = "${aws_s3_bucket.terraform_state.id}"
    key            = "eks/terraform.tfstate"
    region         = "${var.aws_region}"
    dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
    encrypt        = true
  EOT
}
