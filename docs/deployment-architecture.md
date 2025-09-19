# Deployment & Architecture Guide (Template)

## Architecture overview
- VPC: public + private subnets
- EKS cluster: project-bedrock-eks-cluster (k8s v1.32)
- Node groups, IAM roles, in-cluster DBs

## How to access the app
(Provide URL or port-forward instructions after deployment.)

## BedrockDeveloper credentials (IMPORTANT)
- Access Key ID: <paste here>
- Secret Access Key: <paste here>

## How grader can test (example commands)
aws configure --profile BedrockDeveloper
aws eks update-kubeconfig --name project-bedrock-eks-cluster --region <REGION> --profile BedrockDeveloper
kubectl get pods -A
aws ec2 describe-vpcs --region <REGION>

(Replace placeholders and expand before submission.)
