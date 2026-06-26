# Remote state backend (S3 + DynamoDB).
# 1. Run bootstrap once:  cd bootstrap && terraform init && terraform apply
# 2. Copy backend.hcl.example to backend.hcl and fill in bucket/table from bootstrap outputs
# 3. Re-init: terraform init -backend-config=backend.hcl -migrate-state

terraform {
  backend "s3" {}
}
