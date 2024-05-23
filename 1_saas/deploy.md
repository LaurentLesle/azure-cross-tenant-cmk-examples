
```bash
terraform -chdir=./1_saas init

terraform -chdir=./1_saas plan -out plan.tfplan

terraform -chdir=./1_saas apply plan.tfplan
```
