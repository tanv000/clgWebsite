# TravelScape – DevOps Pipeline Implementation

## Overview
**TravelScape** is a simple static travel blog website deployed through an automated **CI/CD pipeline** built using **Jenkins, Docker, Terraform, and AWS**.  
It demonstrates continuous integration, delivery, and infrastructure automation for deploying containerized web applications.

---

## Tech Stack
- **Version Control:** Git & GitHub  
- **CI/CD Automation:** Jenkins  
- **Containerization:** Docker  
- **Infrastructure as Code:** Terraform  
- **Cloud Platform:** AWS (ECR, EC2, IAM, Security Groups)

---

## Workflow
1. **Source Code Management** – Website code and automation scripts stored in GitHub.  
2. **Build Stage** – Jenkins builds a Docker image for the website.  
3. **Push to ECR (Manual Setup)** –  
   - ECR repository is created manually in AWS Console (`website`).  
   - Image is tagged and pushed to the ECR repository.  
4. **Terraform Deployment** – Terraform provisions EC2, IAM, and Security Groups, installs Docker, and pulls the image from ECR.  
5. **Hosting** – EC2 runs the containerized website accessible via public IP.

---

## Manual ECR Setup (Before Pipeline)
1. Open **AWS Console → ECR → Create Repository**.  
2. Name: `website` → Visibility: Private → Create.  
3. Copy URI (e.g.,  
   `708972351530.dkr.ecr.ap-south-1.amazonaws.com/website`).  
4. Update this URI in:
   - `Jenkinsfile` → `ECR_REPO`
   - `variables.tf` → `ecr_repo_url`

---

## Key Files
| File | Purpose |
|------|----------|
| `Jenkinsfile` | Defines pipeline: build → push → deploy |
| `Dockerfile` | Builds static website image |
| `main.tf` | Provisions AWS resources (EC2, IAM, SG) |
| `variables.tf` | Holds configurable parameters |
| `outputs.tf` | Displays EC2 instance details |

---

## Outcome
- Automated deployment of static website to AWS EC2.  
- Integrated Jenkins, Docker, Terraform, and AWS services.  
- Demonstrated full DevOps lifecycle — build, test, deploy, and host.  

