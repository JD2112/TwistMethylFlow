#!/bin/bash

# MethylFlow Docker Image Signing & Push Script
# Signs all 4 images with cosign and pushes to Docker Hub

set -e

# Configuration
IMAGES=(
    "jd21/methylflow-main:1.1.1"
    "jd21/methylflow-enrich:1.1.0"
    "jd21/methylflow-report:1.1.4"
    "jd21/methylflow-unified:1.1.3"
)

# Step 1: Log in to Docker Hub
echo "=== Step 1: Logging in to Docker Hub ==="
# docker login

# Step 2: Push images to Docker Hub
echo ""
echo "=== Step 2: Pushing images to Docker Hub ==="
for image in "${IMAGES[@]}"; do
    echo "Pushing $image..."
    docker push "$image"
    echo "✅ Pushed: $image"
done

# Step 3: Sign images with cosign
echo ""
echo "=== Step 3: Signing images with cosign ==="

# Prompt for cosign password securely
read -sp "Enter password for cosign key: " COSIGN_PASSWORD
export COSIGN_PASSWORD
echo ""

for image in "${IMAGES[@]}"; do
    echo "Signing $image..."
    cosign sign --key ~/.cosign/cosign.key "$image"
    echo "✅ Signed: $image"
done

# Step 4: Verify signatures
echo ""
echo "=== Step 4: Verifying signatures ==="
for image in "${IMAGES[@]}"; do
    echo "Verifying $image..."
    cosign verify --key ~/.cosign/cosign.pub "$image" | head -20
    echo "✅ Verified: $image"
    echo ""
done

echo "=== All images signed and pushed successfully! ==="
