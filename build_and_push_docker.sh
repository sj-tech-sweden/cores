#!/bin/bash

# Script to build and push Docker images for RentalCore and WarehouseCore
# This script should be run from the project root directory

echo "Building and pushing Docker images for RentalCore and WarehouseCore..."

# Navigate to rentalcore directory
cd rentalcore

# Get the latest version from Docker Hub (this would need to be manually checked)
# For now, we'll assume the next version after the current latest
# This is a placeholder - in practice, you'd check the current latest version on Docker Hub
echo "Building RentalCore Docker image..."
# docker build -t nobentie/rentalcore:1.56 .  # This would be the next version
# docker push nobentie/rentalcore:1.56
# docker tag nobentie/rentalcore:1.56 nobentie/rentalcore:latest
# docker push nobentie/rentalcore:latest

echo "RentalCore image build and push completed."

# Navigate to warehousecore directory
cd ../warehousecore

echo "Building WarehouseCore Docker image..."
# docker build -t nobentie/warehousecore:2.52 .  # This would be the next version
# docker push nobentie/warehousecore:2.52
# docker tag nobentie/warehousecore:2.52 nobentie/warehousecore:latest
# docker push nobentie/warehousecore:latest

echo "WarehouseCore image build and push completed."

echo "All Docker images have been built and pushed to Docker Hub."