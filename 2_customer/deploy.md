
```bash
terraform -chdir=./2_customer init

terraform -chdir=./2_customer plan -out plan.tfplan

terraform -chdir=./2_customer apply plan.tfplan
```

