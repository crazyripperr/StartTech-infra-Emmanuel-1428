# StartTech Infrastructure — Emmanuel-1428

> Complete CI/CD pipeline and cloud infrastructure for the StartTech full-stack application.

## 📐 Architecture Overview

```
Internet
    │
    ▼
CloudFront (CDN)          ←── React frontend static files from S3
    │
    ├── /api/* ──────────── Application Load Balancer
    │                            │
    │                   ┌────────┴────────┐
    │                   │                 │
    │               EC2 (t3.micro)   EC2 (t3.micro)   ← Auto Scaling Group
    │               Golang API       Golang API
    │                   │                 │
    │                   └────────┬────────┘
    │                            │
    │                     ElastiCache Redis
    │                     MongoDB Atlas
    │
CloudWatch Logs (monitoring)
```

## 📁 Repository Structure

```
StartTech-infra-emmanuel-1428/
├── .github/workflows/
│   └── infrastructure-deploy.yml   ← Auto-deploys Terraform on push
├── terraform/
│   ├── main.tf                     ← Root module — wires everything together
│   ├── variables.tf                ← Input variables
│   ├── outputs.tf                  ← Important values (URLs, IDs)
│   ├── terraform.tfvars.example    ← Copy → terraform.tfvars and fill in
│   └── modules/
│       ├── networking/             ← VPC, subnets, routing
│       ├── compute/                ← EC2, ALB, ASG, Redis
│       ├── storage/                ← S3, CloudFront
│       └── monitoring/             ← CloudWatch logs & alarms
├── scripts/
│   └── deploy-infrastructure.sh   ← Manual deploy helper
└── monitoring/
    ├── cloudwatch-dashboard.json   ← Import into CloudWatch dashboards
    └── log-insights-queries.txt    ← Useful log search queries
```

---

## 🚀 Step-by-Step Setup Guide (First Time)

### Prerequisites — Install These First

| Tool | Purpose | Install |
|------|---------|---------|
| AWS CLI | Talk to AWS from your terminal | https://aws.amazon.com/cli/ |
| Terraform | Deploy infrastructure | https://terraform.io/downloads |
| Git | Version control | https://git-scm.com |

### Step 1 — Configure AWS CLI

```bash
aws configure
# Enter your:
#   AWS Access Key ID
#   AWS Secret Access Key
#   Default region: us-east-1
#   Output format: json
```

Verify it works:
```bash
aws sts get-caller-identity
```

### Step 2 — Create the Terraform State Bucket

Terraform saves its state (what it has created) in S3. Create the bucket first:

```bash
aws s3 mb s3://starttech-emmanuel-tfstate --region us-east-1

# Enable versioning (so you can recover old state if something goes wrong)
aws s3api put-bucket-versioning \
  --bucket starttech-emmanuel-tfstate \
  --versioning-configuration Status=Enabled
```

### Step 3 — Create an EC2 Key Pair

This is the "key" you'll use to SSH into your servers.

```bash
aws ec2 create-key-pair \
  --key-name starttech-key \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/starttech.pem

chmod 600 ~/.ssh/starttech.pem
```

### Step 4 — Fill in Your Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars   # Edit with your values
```

Fill in:
- `key_name = "starttech-key"`
- `mongo_uri = "mongodb+srv://..."` (from MongoDB Atlas)

### Step 5 — Deploy the Infrastructure

```bash
cd ..
chmod +x scripts/deploy-infrastructure.sh
./scripts/deploy-infrastructure.sh
```

This takes about **10-15 minutes** the first time. It will show you the URLs at the end.

### Step 6 — Note the Outputs

After Terraform finishes, note these values — you'll need them for GitHub secrets:

```bash
cd terraform
terraform output cloudfront_domain        # → your frontend URL
terraform output alb_dns_name             # → your backend URL
terraform output s3_bucket_name           # → S3 bucket name
terraform output cloudfront_distribution_id  # → CF distribution ID
```

---

## 🔐 GitHub Secrets Setup

Go to your **application repo** → Settings → Secrets and variables → Actions.

Add these secrets:

| Secret Name | Value |
|-------------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `S3_BUCKET_NAME` | From `terraform output s3_bucket_name` |
| `CLOUDFRONT_DISTRIBUTION_ID` | From `terraform output cloudfront_distribution_id` |
| `CLOUDFRONT_DOMAIN` | From `terraform output cloudfront_domain` |
| `ALB_DNS_NAME` | From `terraform output alb_dns_name` |
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub → Account Settings → Security → New Token |
| `EC2_SSH_KEY` | Contents of `~/.ssh/starttech.pem` (paste the whole file) |
| `TF_VAR_MONGO_URI` | Your MongoDB Atlas connection string |
| `TF_VAR_KEY_NAME` | `starttech-key` |
| `VITE_API_URL` | `http://<alb-dns-name>` |

---

## 💰 Cost Estimate (With Your $41 Budget)

| Service | Monthly Cost | Notes |
|---------|-------------|-------|
| EC2 t3.micro (1) | ~$8.50 | Free tier eligible first year |
| ElastiCache t3.micro | ~$12 | Smallest Redis node |
| ALB | ~$16 | ~$0.008/LCU-hour |
| CloudFront | ~$0.50 | Very cheap for low traffic |
| S3 | ~$0.10 | Tiny for static files |
| NAT Gateway | ~$5 | Needed for private subnet internet access |
| **Total** | **~$42/month** | Very close to your budget |

**💡 Budget Tips:**
- The NAT Gateway ($5) is the sneaky cost. You can remove it by putting EC2 in public subnets temporarily.
- For this assessment, run it for 1-2 days then `terraform destroy` to avoid charges.

---

## 🔄 How the CI/CD Pipeline Works

### Frontend Pipeline
```
You push code to Client/ folder
        ↓
GitHub Actions starts automatically
        ↓
1. npm install → npm test → npm run build
2. Upload dist/ files to S3
3. Tell CloudFront to serve fresh files
        ↓
Your React app is live!
```

### Backend Pipeline
```
You push code to Server/ folder
        ↓
GitHub Actions starts automatically
        ↓
1. go test ./...
2. docker build → docker push (to Docker Hub)
3. SSH into each EC2 → systemctl restart
4. Smoke test: curl /health → expect 200
        ↓
Your Golang API is live!
```

---

## 🧹 Teardown (Destroy Everything)

When you're done with the assessment, destroy all resources to stop billing:

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted. This deletes everything Terraform created.

---

## 🆘 Troubleshooting

**EC2 instances not healthy in target group?**
- Check Security Group allows port 8080 from ALB
- SSH in and check: `sudo journalctl -u starttech-backend -f`
- Check Docker is running: `sudo docker ps`

**CloudFront showing old content?**
- Invalidation takes 1-5 minutes
- Hard refresh browser: Ctrl+Shift+R

**Terraform error: S3 bucket already exists?**
- Bucket names are globally unique. Change the bucket name in `main.tf`

**Pipeline failing: cannot connect to EC2?**
- Check `EC2_SSH_KEY` secret has the full .pem contents including header/footer lines
