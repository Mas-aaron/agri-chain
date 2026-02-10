#!/bin/bash

# AgriChain Backend Deployment Script
# Usage: ./scripts/deploy-backend.sh [environment]

ENVIRONMENT=${1:-development}
echo "Deploying AgriChain Backend to $ENVIRONMENT environment..."

# Load environment variables
if [ "$ENVIRONMENT" = "production" ]; then
    source backend/backend/.env.production
else
    source backend/backend/.env
fi

# Install dependencies
echo "Installing Python dependencies..."
cd backend/backend
pip install -r requirements.txt

# Run database migrations
echo "Running database migrations..."
python -c "from database import init_database; init_database()"

# Start the API server
echo "Starting API server on $API_HOST:$API_PORT..."
if [ "$ENVIRONMENT" = "production" ]; then
    uvicorn app:app --host $API_HOST --port $API_PORT --workers 4
else
    uvicorn app:app --host $API_HOST --port $API_PORT --reload
fi
