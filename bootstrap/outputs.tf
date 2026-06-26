output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "use_lockfile_name" {
  value = aws_use_lockfile.terraform_locks.name
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
    use_lockfile = "${aws_use_lockfile.terraform_locks.name}"
    encrypt        = true
  EOT
}
