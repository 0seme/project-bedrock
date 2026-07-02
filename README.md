# Project Bedrock — Retail Store Application on Amazon EKS

[![Terraform](https://img.shields.io/badge/Infrastructure-Terraform-623CE4?logo=terraform)](https://terraform.io)
[![AWS](https://img.shields.io/badge/Platform-AWS_EKS-FF9900?logo=amazonaws)](https://aws.amazon.com/eks/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=githubactions)](https://github.com/features/actions)
[![Status](https://img.shields.io/badge/Status-Torn_Down-lightgrey)](#teardown)

A production-style deployment of a retail microservices application onto Amazon EKS —
provisioned end-to-end with Terraform, secured with HTTPS via an ALB, backed by RDS
MySQL, and deployed through a GitHub Actions CI/CD pipeline.

---

## What This Project Does

A containerized retail store application (UI + Catalog services) is deployed onto a
Kubernetes cluster running on Amazon EKS. Terraform provisions the full stack — VPC,
EKS cluster, RDS database, and Application Load Balancer — in a single apply. The ALB
terminates HTTPS traffic and routes it to the catalog service, which persists product
data in RDS MySQL. Terraform state is locked via DynamoDB to make concurrent applies safe.

---

## Architecture

```
Internet
   │
   ▼
Application Load Balancer (public subnets, HTTPS via ACM)
   │
   ▼
EKS Cluster (private subnets, 3 AZs)
   ├── UI Service        (nginx)
   └── Catalog Service    (3 replicas)
              │
              ▼
        RDS MySQL (private subnet, catalog data)
```

- VPC spans 3 availability zones with public subnets (ALB, NAT) and private subnets
  (EKS worker nodes, RDS)
- The AWS Load Balancer Controller creates the ALB automatically from a Kubernetes
  Ingress resource
- Terraform state is stored in S3 with DynamoDB-backed locking

---

## Tech Stack

| Layer                  | Technology                                   |
| ----------------------- | --------------------------------------------- |
| Infrastructure as Code  | Terraform                                     |
| Orchestration           | Kubernetes on Amazon EKS                      |
| Database                | Amazon RDS (MySQL)                            |
| Load Balancing / TLS    | Application Load Balancer + ACM certificate   |
| State Locking           | DynamoDB                                      |
| CI/CD                   | GitHub Actions                                |
| IAM                     | IRSA (IAM Roles for Service Accounts)         |

---

## Project Structure

```
project-bedrock/
├── terraform/
│   ├── main.tf        # VPC, EKS, RDS, ALB, ACM
│   └── backend.tf      # S3 backend + DynamoDB lock table
├── k8s-manifests/
│   ├── catalog-deployment.yaml
│   ├── catalog-service.yaml
│   ├── ui-deployment.yaml
│   ├── ui-service.yaml
│   └── catalog-ingress.yaml
├── .github/workflows/
│   └── deploy.yml      # Terraform plan/apply pipeline
└── README.md
```

---

## Prerequisites

- AWS CLI (v2.x), configured with an IAM user that has EKS/VPC/RDS provisioning permissions
- Terraform ≥ 1.0
- kubectl, matching your target Kubernetes version
- An AWS account with EKS, RDS, and ACM available in your target region

---

## Deployment

```bash
git clone https://github.com/0seme/project-bedrock.git
cd project-bedrock

cd terraform
terraform init
terraform plan
terraform apply

aws eks update-kubeconfig --region <your-region> --name project-bedrock-eks

cd ../k8s-manifests
kubectl apply -f .
kubectl get pods
kubectl get ingress catalog-ingress
```

Terraform provisions the VPC, EKS cluster, RDS instance, and ALB in a single apply.
The Kubernetes manifests deploy the UI and catalog services, and the AWS Load Balancer
Controller creates the ALB from the Ingress resource.

[![CI/CD Pipeline Passing](/Images/Github-actions.png)](/Images/Github-actions.png)

---

## Engineering Decisions Worth Noting

**Self-signed certificate via ACM** — This project didn't use a custom domain, so a
self-signed certificate (generated with the Terraform TLS provider and imported into
ACM) was used to terminate HTTPS on the ALB rather than a CA-issued certificate, which
requires domain validation. In production this would be replaced with a
publicly-trusted certificate tied to a real domain.

**DynamoDB for state locking** — Terraform state is stored in S3 with a DynamoDB table
handling locks, which prevents concurrent applies from corrupting state — standard
practice for any team (or CI pipeline) that might run Terraform at the same time.

**Private subnets for EKS nodes and RDS** — Only the ALB sits in public subnets.
Worker nodes and the database are in private subnets, reachable only through
security-group rules scoped to what actually needs to talk to them (ALB → nodes on
the app port, nodes → RDS on 3306).

**IRSA over static credentials** — The AWS Load Balancer Controller authenticates via
IAM Roles for Service Accounts rather than long-lived credentials baked into the
cluster, keeping AWS permissions scoped per-service rather than per-node.

---

## Security Notes

- No AWS credentials are hardcoded anywhere in this repo — CI/CD authenticates via
  GitHub Actions secrets
- Database credentials are passed as Kubernetes environment variables at deploy time,
  not committed to the repo
- IAM roles follow least-privilege scoping per service (cluster role, node role, and
  load balancer controller role are all separate)
- In production, the self-signed certificate would be replaced with a CA-issued cert,
  and database credentials would move to AWS Secrets Manager rather than plain
  environment variables

---

## Teardown

```bash
kubectl delete -f k8s-manifests/
# wait for the ALB to finish deleting before destroying the VPC
cd terraform
terraform destroy
```

All resources for this project have been destroyed. The ALB must fully delete before
`terraform destroy` runs, or VPC deletion will fail with dependency errors.

---

## Author

**Joyce (Koko)** ☁️ [@0seme](https://github.com/0seme)

*Part of an ongoing AWS DevOps portfolio — building toward AWS DevOps Professional certification.*

---

## License

This project was built for educational purposes as part of a cloud engineering course.
