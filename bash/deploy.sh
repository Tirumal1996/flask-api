#!/bin/bash

set -e  # Exit on any command failure
set -u  # Treat unset variables as errors

# Variables
AWS_ACCOUNT_ID="$1"
if [[ -z "$AWS_ACCOUNT_ID" ]]; then
    echo "Error: AWS_ACCOUNT_ID is required as the first argument."
    exit 1
fi

AWS_REGION="us-east-1"
ECR_REPO_NAME="flask-api"
IMAGE_TAG="latest"
CLUSTER_NAME="flask-cluster"
SERVICE_NAME="flask-service"
HEALTH_CHECK_URL="http://$2:5000"
if [[ -z "$2" ]]; then
    echo "Error: ECS Service Load Balancer DNS/IP is required as the second argument."
    exit 1
fi
NAME="flask-api"
GIT_REPO="https://github.com/Tirumal1996/$NAME.git"

function log_info {
    echo "[INFO] $1"
}

function log_error {
    echo "[ERROR] $1"
    exit 1
}

aws sts get-caller-identity &>/dev/null || log_error "AWS CLI not configured properly"

# Clone Repository
log_info "Cloning the repository: $GIT_REPO"
if [[ -d "$NAME" ]]; then
    cd "$NAME"
    git pull || log_error "Failed to pull latest changes"
else
    git clone "$GIT_REPO" || log_error "Failed to clone repository"
    cd "$NAME"
fi

# Build and push Docker image
log_info "Building and pushing Docker image"
aws ecr get-login-password --region "$AWS_REGION" | sudo docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
sudo docker build -t "$ECR_REPO_NAME:$IMAGE_TAG" .
sudo docker tag "$ECR_REPO_NAME:$IMAGE_TAG" "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG"
sudo docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG"

# Update ECS service
log_info "Updating ECS service"
aws ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --force-new-deployment

# Health check
log_info "Performing health check"
timeout=300
until curl -s -f "$HEALTH_CHECK_URL/health" || [ $timeout -le 0 ]; do
    log_info "Waiting for service to be healthy... ($timeout seconds remaining)"
    ((timeout-=5))
    sleep 5
done

if [ $timeout -le 0 ]; then
    log_error "Health check failed after timeout"
else
    log_info "Deployment completed successfully!"
fi

# Cleanup
log_info "Cleaning up local resources"
sudo docker rmi "$ECR_REPO_NAME:$IMAGE_TAG" "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG"