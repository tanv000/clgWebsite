#!/bin/bash
# deploy.sh
# This script is executed remotely on the EC2 Docker host to deploy the application.

# Arguments:
# $1: IMAGE_TAG (e.g., latest)

# Set -e to exit immediately if any command fails
set -e

# --- 1. Variable Setup ---
IMAGE_TAG="$1" 
IMAGE_REPO_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}"

echo "Starting deployment for image: $IMAGE_REPO_URL:$IMAGE_TAG"

# --- 2. ECR Login ---
echo "Attempting ECR login..."

# Login to ECR using the attached IAM role on the EC2 host.
# The entire command substitution must be wrapped to ensure the token is piped correctly.
# The 'bash -lc' in Jenkins ensures the 'aws' command is in the PATH.
$(aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin $IMAGE_REPO_URL)

if [ $? -ne 0 ]; then
    echo "ERROR: Docker login failed on EC2 host. Check IAM role permissions."
    exit 1
fi

# --- 3. Container Management (Idempotency) ---
echo "Stopping and removing old container if it exists..."
# '|| true' ensures the script doesn't fail if the container doesn't exist.
docker stop web-app-container || true
docker rm web-app-container || true

# --- 4. Pull and Run New Container ---
echo "Pulling latest image from ECR: $IMAGE_REPO_URL:$IMAGE_TAG"
docker pull $IMAGE_REPO_URL:$IMAGE_TAG

if [ $? -ne 0 ]; then
    echo "ERROR: Docker pull failed. Check image tag and ECR permissions."
    exit 1
fi

echo "Running new container on port 80..."
# Run the container detached (-d) and map host port 80 to container port 80 (-p 80:80)
docker run -d -p 80:80 --name web-app-container $IMAGE_REPO_URL:$IMAGE_TAG

if [ $? -ne 0 ]; then
    echo "ERROR: Docker run failed. Check container logs."
    exit 1
fi

echo "✅ Deployment successful. Container web-app-container is running."