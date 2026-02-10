#!/bin/bash

# AgriChain Frontend Deployment Script
# Usage: ./scripts/deploy-frontend.sh [environment]

ENVIRONMENT=${1:-development}
echo "Deploying AgriChain Frontend to $ENVIRONMENT environment..."

# Load environment variables
cd agri-chain
if [ "$ENVIRONMENT" = "production" ]; then
    source .env.production
else
    source .env
fi

# Install Flutter dependencies
echo "Installing Flutter dependencies..."
flutter pub get

# Build the app
if [ "$ENVIRONMENT" = "production" ]; then
    echo "Building production release..."
    flutter build web --release --dart-define=FLUTTER_ENV=production
    flutter build apk --release --dart-define=FLUTTER_ENV=production
    flutter build ios --release --dart-define=FLUTTER_ENV=production
else
    echo "Building development version..."
    flutter build web --debug --dart-define=FLUTTER_ENV=development
fi

echo "Frontend deployment complete!"
