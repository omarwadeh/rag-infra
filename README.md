# RAG Infrastructure Handover Document

**Project**:  RAG Infrastructure Deployment  
**Repository**: omarwadeh/rag-infra  
**Version**: 1.0  
**Date**: 2026-01-07  
**Target Audience**: Technical teams responsible for deployment and operations

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Prerequisites](#prerequisites)
3. [Architecture Overview](#architecture-overview)
4. [Pre-Deployment Checklist](#pre-deployment-checklist)
5. [Deployment Instructions](#deployment-instructions)
6. [Post-Deployment Verification](#post-deployment-verification)
7. [Configuration Management](#configuration-management)
8. [Troubleshooting](#troubleshooting)
9. [Maintenance and Operations](#maintenance-and-operations)
10. [Rollback Procedures](#rollback-procedures)
11. [Cost Estimation](#cost-estimation)
12. [Support and Contacts](#support-and-contacts)

---

## Executive Summary

This document provides complete instructions for deploying the RAG (Retrieval-Augmented Generation) infrastructure in your AWS environment. The infrastructure consists of:

- **AWS VPC**: Isolated network environment with public and private subnets
- **Amazon EKS**:  Managed Kubernetes cluster for container orchestration
- **Kubernetes Workloads**: Application components for RAG functionality

**Deployment Time**:  Approximately 45-60 minutes  
**Required Skill Level**: Intermediate AWS and Kubernetes knowledge  
**Cloud Provider**: Amazon Web Services (AWS)

---

## Prerequisites

### Required Accounts and Access

- **AWS Account** with administrative access or the following permissions:
  - EC2 (VPC, Subnets, Security Groups, NAT Gateways)
  - EKS (Cluster creation and management)
  - IAM (Role and policy creation)
  - CloudFormation (Stack management)
- **GitHub Account** (to clone the repository)

### Required Tools

Install the following tools on your deployment machine:

| Tool | Version | Installation Guide |
|------|---------|-------------------|
| AWS CLI | v2.x | Use bundled installer in `aws/` folder or [AWS Docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Terraform | ≥ 1.0 | [Terraform Install Guide](https://developer.hashicorp.com/terraform/install) |
| kubectl | ≥ 1.28 | [Kubernetes Install Guide](https://kubernetes.io/docs/tasks/tools/) |
| Git | Latest | [Git Install Guide](https://git-scm.com/downloads) |

### AWS Credentials Configuration

Configure AWS credentials using one of the following methods:

**Option 1: AWS CLI Configuration**
```bash
aws configure
```
Provide: 
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `eu-west-1`)
- Default output format (e.g., `json`)

**Option 2: Environment Variables**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-west-1"
```

**Option 3: IAM Role (for EC2/Cloud environments)**
- Attach an IAM role with required permissions to your deployment instance

### Network Requirements

- Internet connectivity for downloading Terraform providers and Kubernetes images
- Outbound HTTPS (443) access to AWS APIs
- Outbound access to Docker Hub and public container registries

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      AWS Cloud                          │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │              VPC (10.0.0.0/16)                    │ │
│  │                                                   │ │
│  │  ┌──────────────────┐    ┌──────────────────┐   │ │
│  │  │  Public Subnets  │    │  Private Subnets │   │ │
│  │  │  - NAT Gateway   │    │  - EKS Nodes     │   │ │
│  │  │  - Internet GW   │    │  - Application   │   │ │
│  │  └──────────────────┘    └──────────────────┘   │ │
│  │                                                   │ │
│  │  ┌─────────────────────────────────────────────┐ │ │
│  │  │         Amazon EKS Cluster                  │ │ │
│  │  │  - Control Plane (Managed)                  │ │ │
│  │  │  - Worker Nodes (EC2)                       │ │ │
│  │  │  - RAG Application Pods                     │ │ │
│  │  └─────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Component Descriptions

**VPC Module** (`infrastructure/terraform/vpc/`)
- Creates isolated network environment
- Provisions public and private subnets across multiple availability zones
- Configures NAT Gateways for private subnet internet access
- Sets up routing tables and security groups

**EKS Module** (`infrastructure/terraform/eks/`)
- Provisions managed Kubernetes control plane
- Creates node groups for worker instances
- Configures IAM roles for service accounts (IRSA)
- Sets up cluster authentication and authorization

**Kubernetes Workloads** (`infrastructure/k8s/`)
- Application deployments for RAG components
- Service definitions for internal and external access
- ConfigMaps and Secrets for configuration

---

## Pre-Deployment Checklist

Before beginning deployment, verify the following:

- [ ] AWS account access confirmed with required permissions
- [ ] All required tools installed and versions verified
- [ ] AWS credentials configured and tested (`aws sts get-caller-identity`)
- [ ] Target AWS region selected and documented
- [ ] Budget and cost limits understood and approved
- [ ] Backup and disaster recovery requirements defined
- [ ] Security compliance requirements reviewed
- [ ] Naming conventions and tagging strategy defined

### Environment Variables

Create a file `deployment. env` with your deployment-specific values:

```bash
# AWS Configuration
export AWS_REGION="eu-west-1"
export AWS_ACCOUNT_ID="123456789012"

# Project Configuration
export PROJECT_NAME="rag-infra"
export ENVIRONMENT="production"  # or:  development, staging

# Terraform State (Optional - for remote state)
export TF_STATE_BUCKET="my-terraform-state-bucket"
export TF_STATE_KEY="rag-infra/terraform.tfstate"

# EKS Configuration
export CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
export K8S_VERSION="1.28"
export NODE_INSTANCE_TYPE="t3.medium"
export NODE_COUNT="3"
```

Load the environment: 
```bash
source deployment.env
```

---

## Deployment Instructions

### Step 1: Clone the Repository

```bash
git clone https://github.com/omarwadeh/rag-infra.git
cd rag-infra
```

### Step 2: Install AWS CLI (if not already installed)

```bash
cd aws
sudo ./install
aws --version
cd ..
```

Verify installation:
```bash
aws sts get-caller-identity
```

Expected output showing your AWS account details. 

### Step 3: Deploy VPC Infrastructure

```bash
cd infrastructure/terraform/vpc
```

**Initialize Terraform**
```bash
terraform init
```

**Review the configuration**

Edit `terraform.tfvars` or create it with your values:
```hcl
region               = "eu-west-1"
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
project_name         = "rag-infra"
environment          = "production"
```

**Plan the deployment**
```bash
terraform plan -out=vpc. tfplan
```

Review the plan carefully.  Verify: 
- Correct number of subnets
- Proper CIDR ranges
- Expected resource counts

**Apply the configuration**
```bash
terraform apply vpc.tfplan
```

This will take approximately 5-10 minutes. 

**Capture outputs**
```bash
terraform output -json > vpc_outputs.json
```

Save these outputs for the next step.

### Step 4: Deploy EKS Cluster

```bash
cd ../eks
```

**Initialize Terraform**
```bash
terraform init
```

**Configure EKS variables**

Edit `terraform.tfvars`:
```hcl
region            = "eu-west-1"
cluster_name      = "rag-infra-production"
cluster_version   = "1.28"
vpc_id            = "vpc-xxxxx"  # From VPC outputs
private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy", "subnet-zzzzz"]  # From VPC outputs

# Node Group Configuration
node_group_name          = "rag-workers"
node_instance_types      = ["t3.medium"]
node_desired_size        = 3
node_min_size            = 2
node_max_size            = 5
node_disk_size           = 50

project_name    = "rag-infra"
environment     = "production"
```

**Important**:  Replace `vpc_id` and `private_subnet_ids` with actual values from VPC outputs.

**Plan the deployment**
```bash
terraform plan -out=eks.tfplan
```

**Apply the configuration**
```bash
terraform apply eks.tfplan
```

This will take approximately 15-20 minutes.

### Step 5: Configure kubectl Access

**Update kubeconfig**
```bash
aws eks update-kubeconfig \
  --region eu-west-1 \
  --name rag-infra-production
```

**Verify cluster access**
```bash
kubectl get nodes
```

Expected output:  List of worker nodes in `Ready` state.

```bash
kubectl get namespaces
```

### Step 6: Deploy Kubernetes Applications

```bash
cd ../../k8s
```

**Review manifests**

Inspect the YAML files in this directory and update any environment-specific values: 
- Image repositories
- Resource limits
- Environment variables
- Ingress hostnames

**Apply Kubernetes manifests**
```bash
kubectl apply -f . 
```

Or apply them in order if dependencies exist:
```bash
kubectl apply -f namespaces/
kubectl apply -f configmaps/
kubectl apply -f secrets/
kubectl apply -f deployments/
kubectl apply -f services/
```

**Monitor deployment**
```bash
kubectl get pods -A -w
```

Wait until all pods show `Running` or `Completed` status.

---

## Post-Deployment Verification

### Infrastructure Verification

**1.  Verify VPC Resources**
```bash
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=rag-infra-production"
aws ec2 describe-subnets --filters "Name=tag:Name,Values=*rag-infra*"
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"
```

**2. Verify EKS Cluster**
```bash
aws eks describe-cluster --name rag-infra-production --region eu-west-1
kubectl cluster-info
kubectl get nodes -o wide
```

**3. Verify IAM Roles**
```bash
aws iam list-roles | grep rag-infra
```

### Application Verification

**1. Check Pod Status**
```bash
kubectl get pods -A
```

All pods should be in `Running` state.

**2. Check Services**
```bash
kubectl get services -A
```

Verify LoadBalancer or NodePort services have external endpoints.

**3. Check Logs**
```bash
kubectl logs -n default <pod-name>
```

Look for successful startup messages.

**4. Test Application Endpoints**

If LoadBalancer is provisioned:
```bash
kubectl get svc -n default
# Copy EXTERNAL-IP and test
curl http://<EXTERNAL-IP>
```

### Health Checks

**EKS Cluster Health**
```bash
aws eks describe-cluster \
  --name rag-infra-production \
  --query 'cluster.status' \
  --output text
```

Should return:  `ACTIVE`

**Node Health**
```bash
kubectl get nodes
kubectl top nodes  # Requires metrics-server
```

**Resource Quotas**
```bash
kubectl describe resourcequota -A
```

---

## Configuration Management

### Terraform State Management

**Current State Location**
By default, Terraform state is stored locally in each module directory: 
- `infrastructure/terraform/vpc/terraform.tfstate`
- `infrastructure/terraform/eks/terraform.tfstate`

**Recommended:  Remote State Backend**

For production, configure S3 backend for state storage:

1. Create S3 bucket for state:
```bash
aws s3api create-bucket \
  --bucket my-rag-terraform-state \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

aws s3api put-bucket-versioning \
  --bucket my-rag-terraform-state \
  --versioning-configuration Status=Enabled
```

2. Create DynamoDB table for state locking: 
```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-1
```

3. Add backend configuration to each Terraform module: 

```hcl
# infrastructure/terraform/vpc/backend.tf
terraform {
  backend "s3" {
    bucket         = "my-rag-terraform-state"
    key            = "vpc/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

4. Re-initialize Terraform:
```bash
terraform init -migrate-state
```

### Secrets Management

**AWS Secrets Manager**

Store sensitive data in AWS Secrets Manager: 
```bash
aws secretsmanager create-secret \
  --name rag-infra/database-password \
  --secret-string "your-secure-password" \
  --region eu-west-1
```

**Kubernetes Secrets**

Create Kubernetes secrets for application use:
```bash
kubectl create secret generic app-secrets \
  --from-literal=api-key=your-api-key \
  --from-literal=db-password=your-db-password
```

**External Secrets Operator (Recommended)**

For synchronizing AWS Secrets Manager with Kubernetes: 
1. Install External Secrets Operator
2. Configure SecretStore pointing to AWS Secrets Manager
3. Create ExternalSecret resources

### Environment-Specific Configuration

Maintain separate configurations for each environment:

```
infrastructure/terraform/
├── vpc/
│   ├── environments/
│   │   ├── dev. tfvars
│   │   ├── staging.tfvars
│   │   └── production.tfvars
│   └── main.tf
└── eks/
    ├── environments/
    │   ├── dev.tfvars
    │   ├── staging.tfvars
    │   └── production.tfvars
    └── main.tf
```

Deploy with: 
```bash
terraform apply -var-file=environments/production.tfvars
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Terraform Authentication Errors

**Symptom**: 
```
Error: error configuring Terraform AWS Provider: no valid credential sources
```

**Solution**:
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Re-configure if needed
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
```

#### Issue 2: EKS Node Groups Not Joining Cluster

**Symptom**: 
Nodes show `NotReady` or don't appear in `kubectl get nodes`

**Solution**:
```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name rag-infra-production \
  --nodegroup-name rag-workers

# Check IAM role trust relationship
aws iam get-role --role-name <node-role-name>

# Verify security groups allow kubelet communication
aws ec2 describe-security-groups --group-ids <cluster-sg-id>
```

#### Issue 3: Pods in Pending State

**Symptom**:
```bash
kubectl get pods
NAME                    READY   STATUS    RESTARTS   AGE
app-xxx                 0/1     Pending   0          5m
```

**Solution**:
```bash
# Check pod events
kubectl describe pod app-xxx

# Common causes:
# 1. Insufficient resources
kubectl top nodes
kubectl describe nodes

# 2. Image pull errors
kubectl describe pod app-xxx | grep -A 10 Events

# 3. PersistentVolumeClaim issues
kubectl get pvc
```

#### Issue 4: Terraform State Lock

**Symptom**: 
```
Error: Error locking state: Error acquiring the state lock
```

**Solution**:
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>

# Or manually release from DynamoDB
aws dynamodb delete-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S":"<lock-id>"}}'
```

#### Issue 5: kubectl Connection Refused

**Symptom**: 
```
The connection to the server localhost:8080 was refused
```

**Solution**:
```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --region eu-west-1 \
  --name rag-infra-production

# Verify context
kubectl config current-context

# Check cluster endpoint
aws eks describe-cluster \
  --name rag-infra-production \
  --query 'cluster.endpoint'
```

### Diagnostic Commands

**Collect cluster information**
```bash
kubectl cluster-info dump > cluster-dump.txt
```

**Check AWS CloudWatch Logs**
```bash
aws logs tail /aws/eks/rag-infra-production/cluster --follow
```

**Terraform debugging**
```bash
export TF_LOG=DEBUG
terraform apply
```

---

## Maintenance and Operations

### Regular Maintenance Tasks

#### Daily
- [ ] Monitor pod health:  `kubectl get pods -A`
- [ ] Check node status: `kubectl get nodes`
- [ ] Review application logs for errors

#### Weekly
- [ ] Review AWS Cost Explorer for unexpected charges
- [ ] Check EKS control plane logs in CloudWatch
- [ ] Verify backup completion (if configured)
- [ ] Review security group rules and IAM policies

#### Monthly
- [ ] Update Kubernetes applications to latest versions
- [ ] Review and rotate secrets/credentials
- [ ] Patch EKS cluster to latest minor version
- [ ] Review and optimize resource requests/limits
- [ ] Audit IAM permissions and remove unused roles

#### Quarterly
- [ ] Major version upgrades (EKS, Kubernetes apps)
- [ ] Infrastructure cost optimization review
- [ ] Disaster recovery drill
- [ ] Security compliance audit

### Scaling Operations

**Scale Node Groups**
```bash
# Via Terraform
# Edit terraform.tfvars:
node_desired_size = 5

terraform apply

# Or via AWS CLI
aws eks update-nodegroup-config \
  --cluster-name rag-infra-production \
  --nodegroup-name rag-workers \
  --scaling-config desiredSize=5,minSize=3,maxSize=10
```

**Scale Application Pods**
```bash
# Manual scaling
kubectl scale deployment app-name --replicas=5

# Horizontal Pod Autoscaler
kubectl autoscale deployment app-name \
  --min=2 \
  --max=10 \
  --cpu-percent=70
```

### Backup Procedures

**EKS Configuration Backup**
```bash
# Backup cluster configuration
aws eks describe-cluster \
  --name rag-infra-production \
  > backups/eks-cluster-$(date +%Y%m%d).json

# Backup Kubernetes resources
kubectl get all -A -o yaml > backups/k8s-resources-$(date +%Y%m%d).yaml
```

**Terraform State Backup**
```bash
# If using local state
cp infrastructure/terraform/vpc/terraform.tfstate \
   backups/vpc-tfstate-$(date +%Y%m%d).backup

# If using S3 backend, enable versioning (already recommended)
```

### Monitoring Setup

**AWS CloudWatch Container Insights**
```bash
# Install CloudWatch agent
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml
```

**Prometheus and Grafana (Recommended)**
```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### Logging

**Enable EKS Control Plane Logging**
```bash
aws eks update-cluster-config \
  --name rag-infra-production \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'
```

**Application Logging**
```bash
# View logs
kubectl logs -f deployment/app-name

# Aggregate logs with Fluentd/Fluent Bit (recommended)
# Configure to send to CloudWatch, Elasticsearch, or S3
```

---

## Rollback Procedures

### Kubernetes Application Rollback

**Rollback to previous deployment**
```bash
# Check rollout history
kubectl rollout history deployment/app-name

# Rollback to previous version
kubectl rollout undo deployment/app-name

# Rollback to specific revision
kubectl rollout undo deployment/app-name --to-revision=3
```

### Terraform Rollback

**Rollback infrastructure changes**
```bash
# Option 1: Revert to previous state file
cd infrastructure/terraform/eks
cp terraform.tfstate. backup terraform.tfstate
terraform apply

# Option 2: Use version control
git revert <commit-hash>
terraform apply

# Option 3: Targeted resource replacement
terraform state list
terraform taint aws_eks_cluster.main
terraform apply
```

### Complete Environment Rollback

If a deployment fails critically: 

1. **Restore from backup**
   ```bash
   # Restore Terraform state
   aws s3 cp s3://my-rag-terraform-state/vpc/terraform.tfstate. backup \
     infrastructure/terraform/vpc/terraform.tfstate
   
   # Restore Kubernetes resources
   kubectl apply -f backups/k8s-resources-20260106.yaml
   ```

2. **Rebuild from known-good configuration**
   ```bash
   git checkout <previous-stable-tag>
   cd infrastructure/terraform/eks
   terraform apply
   ```

3. **Document incident**
   - What failed
   - Steps taken
   - Resolution time
   - Lessons learned

---

## Cost Estimation

### Monthly Cost Breakdown (EU-West-1)

| Component | Specification | Estimated Monthly Cost (USD) |
|-----------|--------------|------------------------------|
| EKS Control Plane | 1 cluster | $73 |
| EC2 Node Group | 3x t3.medium (24/7) | ~$90 |
| NAT Gateway | 1x NAT Gateway | ~$33 + data transfer |
| EBS Volumes | 3x 50GB gp3 | ~$15 |
| Data Transfer | 100GB outbound | ~$9 |
| CloudWatch Logs | 10GB/month | ~$5 |
| **Total Estimated** | | **~$225/month** |

**Cost Optimization Tips**:
- Use Spot Instances for non-critical node groups (50-70% savings)
- Implement cluster autoscaler to scale down during low usage
- Use S3 Gateway Endpoint (free) instead of NAT for S3 access
- Enable EBS volume encryption without additional cost
- Review and delete unused EBS volumes and snapshots

### Cost Monitoring

**Set up billing alerts**
```bash
aws budgets create-budget \
  --account-id 123456789012 \
  --budget file://budget-config.json
```

**budget-config.json**: 
```json
{
  "BudgetName": "RAG-Infrastructure-Budget",
  "BudgetLimit": {
    "Amount": "300",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
```

**Tag resources for cost allocation**
```hcl
tags = {
  Project     = "rag-infra"
  Environment = "production"
  ManagedBy   = "terraform"
  CostCenter  = "engineering"
}
```

---

## Support and Contacts

### Repository Information

- **Repository**: https://github.com/omarwadeh/rag-infra
- **Original Source**: https://github.com/Mazenalic12/rag-infra (forked)
- **Documentation**: See `README.md` in repository root

### Getting Help

**For deployment issues**:
1. Check this handover document
2. Review Troubleshooting section
3. Check AWS service health dashboard
4. Consult Terraform and AWS documentation

**Reporting Issues**:
- Create GitHub issue with: 
  - Deployment environment details
  - Error messages and logs
  - Steps to reproduce
  - Expected vs.  actual behavior

### Useful Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

### Emergency Contacts

| Role | Contact | Availability |
|------|---------|--------------|
| Infrastructure Owner | omarwadeh (GitHub) | Email/Issues |
| AWS Support | AWS Console → Support | 24/7 (if subscribed) |
| On-call Engineer | [Your contact] | [Your hours] |

---

## Appendix

### A. Complete Deployment Script

Save as `deploy.sh`:

```bash
#!/bin/bash
set -e

# Load environment
source deployment. env

echo "=== RAG Infrastructure Deployment ==="
echo "Region: $AWS_REGION"
echo "Environment: $ENVIRONMENT"
echo ""

# Step 1: VPC
echo "Step 1: Deploying VPC..."
cd infrastructure/terraform/vpc
terraform init
terraform plan -out=vpc. tfplan
terraform apply vpc.tfplan
terraform output -json > ../../../vpc_outputs.json
cd ../../.. 

# Step 2: EKS
echo "Step 2: Deploying EKS Cluster..."
cd infrastructure/terraform/eks
terraform init
terraform plan -out=eks.tfplan
terraform apply eks. tfplan
cd ../../..

# Step 3: Configure kubectl
echo "Step 3: Configuring kubectl..."
aws eks update-kubeconfig \
  --region $AWS_REGION \
  --name $CLUSTER_NAME

# Step 4: Deploy K8s workloads
echo "Step 4: Deploying Kubernetes workloads..."
kubectl apply -f infrastructure/k8s/

echo "=== Deployment Complete ==="
echo "Run: kubectl get pods -A"
```

Make executable:
```bash
chmod +x deploy.sh
./deploy.sh
```

### B. Destruction Script

Save as `destroy.sh`:

```bash
#!/bin/bash
set -e

echo "WARNING: This will destroy all infrastructure!"
read -p "Type 'yes' to continue: " confirm

if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

# Delete Kubernetes resources
echo "Deleting Kubernetes resources..."
kubectl delete -f infrastructure/k8s/ --ignore-not-found=true

# Wait for LoadBalancers to be deleted
echo "Waiting for LoadBalancers to be deleted..."
sleep 30

# Destroy EKS
echo "Destroying EKS cluster..."
cd infrastructure/terraform/eks
terraform destroy -auto-approve
cd ../../.. 

# Destroy VPC
echo "Destroying VPC..."
cd infrastructure/terraform/vpc
terraform destroy -auto-approve
cd ../../..

echo "=== Destruction Complete ==="
```

Make executable:
```bash
chmod +x destroy.sh
./destroy.sh
```

### C. Health Check Script

Save as `health-check.sh`:

```bash
#!/bin/bash

echo "=== RAG Infrastructure Health Check ==="
echo ""

# Check AWS connectivity
echo "1. AWS Connectivity:"
aws sts get-caller-identity && echo "✓ AWS connection OK" || echo "✗ AWS connection failed"
echo ""

# Check EKS cluster
echo "2. EKS Cluster Status:"
CLUSTER_STATUS=$(aws eks describe-cluster --name rag-infra-production --query 'cluster.status' --output text 2>/dev/null)
if [ "$CLUSTER_STATUS" == "ACTIVE" ]; then
  echo "✓ Cluster is ACTIVE"
else
  echo "✗ Cluster status: $CLUSTER_STATUS"
fi
echo ""

# Check nodes
echo "3. Node Status:"
kubectl get nodes --no-headers 2>/dev/null | awk '{print $1, $2}' || echo "✗ Cannot connect to cluster"
echo ""

# Check pods
echo "4. Pod Status:"
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null
FAILING_PODS=$?
if [ $FAILING_PODS -eq 0 ]; then
  echo "✓ All pods healthy"
else
  echo "✗ Some pods are not running"
fi
echo ""

# Check services
echo "5. Services:"
kubectl get svc -A 2>/dev/null || echo "✗ Cannot retrieve services"
echo ""

echo "=== Health Check Complete ==="
```

Make executable:
```bash
chmod +x health-check.sh
./health-check. sh
```

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-07 | omarwadeh | Initial handover document |

---

**END OF HANDOVER DOCUMENT**
