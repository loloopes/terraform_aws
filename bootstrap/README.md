# Remote Terraform state (one-time)

Creates an **S3 bucket** (versioned, encrypted) and **DynamoDB table** for state locking.

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

Copy the backend config into the main stack:

```bash
terraform output -raw backend_config > ../backend.hcl
# Or: cp ../backend.hcl.example ../backend.hcl and fill in bucket/table names

cd ..
terraform init -backend-config=backend.hcl -migrate-state
```

Or use `make bootstrap` and `make init` from the `terraform/` directory.

**Note:** Bootstrap uses **local state** by design (chicken-and-egg). Keep the bootstrap state file safe or check it into a secure location.
