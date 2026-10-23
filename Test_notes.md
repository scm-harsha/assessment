1. Start Floci container
```bash 
podman compose up -d
```

2. Set ENV:
```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

3. Create Dynamodb
```bash
aws dynamodb create-table \
       --table-name terraform-state-lock-dev \
       --attribute-definitions AttributeName=LockID,AttributeType=S \
       --key-schema AttributeName=LockID,KeyType=HASH \
       --billing-mode PAY_PER_REQUEST \
       --region us-east-1
```

4. Create S3 bucket:
```bash 
aws s3 mb s3://tf-state --region=us-east-1
```

5. Initialize Terraform
Note: make sure you updated with valid subnet ids in  tfvars file
```bash
terraform -chdir=envs/dev init
```

6. Plan
```bash
terraform -chdir=envs/dev plan
```

7. Apply Terraform
```bash
terraform -chdir=envs/dev apply --auto-approve=true
```

8. Destroy Terraform
```bash
terraform -chdir=envs/dev destroy --auto-approve=true
```