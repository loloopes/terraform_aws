.PHONY: init init-local bootstrap bootstrap-init bootstrap-setup plan apply destroy output kubeconfig push-images deploy-platform verify-aws

WITH_ENV = bash scripts/with-env.sh

init-local:
	$(WITH_ENV) terraform init -backend=false -reconfigure

init:
	@if [ ! -f backend.hcl ]; then \
	  echo "ERROR: backend.hcl not found."; \
	  echo "  Remote state:  make bootstrap-setup"; \
	  echo "  Local state:   make init-local"; \
	  exit 1; \
	fi
	$(WITH_ENV) terraform init -backend-config=backend.hcl

bootstrap-init:
	$(WITH_ENV) terraform -chdir=bootstrap init

bootstrap:
	$(WITH_ENV) terraform -chdir=bootstrap apply

bootstrap-setup: bootstrap-init bootstrap
	$(WITH_ENV) terraform -chdir=bootstrap output -raw backend_config > backend.hcl
	@echo "==> Created backend.hcl"
	$(WITH_ENV) terraform init -backend-config=backend.hcl
	@echo "==> Main stack initialized with remote state. Run: make plan"

bootstrap-output:
	$(WITH_ENV) terraform -chdir=bootstrap output

verify-aws:
	$(WITH_ENV) aws sts get-caller-identity

# kubectl talks to EKS via `aws eks get-token` — load .env first (or use `aws configure`).
kubectl:
	$(WITH_ENV) kubectl $(ARGS)

plan:
	@if [ ! -d .terraform ]; then \
	  echo "ERROR: Terraform not initialized."; \
	  echo "  Remote state:  make bootstrap-setup   (or: make init)"; \
	  echo "  Local state:   make init-local"; \
	  exit 1; \
	fi
	$(WITH_ENV) terraform plan

apply:
	$(WITH_ENV) terraform apply

destroy:
	$(WITH_ENV) terraform destroy

output:
	$(WITH_ENV) terraform output

kubeconfig:
	$(WITH_ENV) bash scripts/kubeconfig.sh

setup-hosts:
	$(WITH_ENV) bash scripts/setup-hosts.sh

push-images:
	$(WITH_ENV) bash ../k8s/scripts/push-images-ecr.sh

deploy-platform:
	$(WITH_ENV) bash ../k8s/scripts/deploy-eks.sh
