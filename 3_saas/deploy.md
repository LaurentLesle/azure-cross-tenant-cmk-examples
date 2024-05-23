
```bash
terraform -chdir=./3_saas init

terraform -chdir=./3_saas plan -out plan.tfplan

terraform -chdir=./3_saas apply plan.tfplan
```

