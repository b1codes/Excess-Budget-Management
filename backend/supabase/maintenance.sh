#!/bin/bash

# Maintenance script for Production Supabase Environment
# This script helps sync migrations, deploy functions, and perform a health check (heartbeat).

# Prerequisites:
# 1. Supabase CLI installed
# 2. Logged in via `supabase login`
# 3. Environment variables set:
#    - SUPABASE_PROJECT_ID: The ID of your production project (e.g., 'abcdefghijk')
#    - SUPABASE_ACCESS_TOKEN: Your personal access token (optional if logged in via CLI)

set -e

# Load environment variables if .env file exists
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

PROJECT_ID=${SUPABASE_PROJECT_ID}

if [ -z "$PROJECT_ID" ]; then
  echo "Error: SUPABASE_PROJECT_ID is not set."
  echo "Please set it in your environment or a .env file."
  exit 1
fi

echo "--- Starting Supabase Maintenance Routine ---"
echo "Project ID: $PROJECT_ID"

# 1. Migration Sync
echo ""
echo "Step 1: Syncing migrations to production..."
# Note: Use --linked if you have already linked the project
# This command pushes local migrations that haven't been applied yet.
supabase db push --project-ref "$PROJECT_ID"

# 2. Function Deployment
echo ""
echo "Step 2: Deploying Edge Functions..."
supabase functions deploy --project-ref "$PROJECT_ID"

# 3. Activity Heartbeat (Health Check)
echo ""
echo "Step 3: Performing Health Check (Activity Heartbeat)..."
# Replace with your actual project URL if different
HEALTH_CHECK_URL="https://$PROJECT_ID.supabase.co/functions/v1/health-check"

response=$(curl -s -w "\n%{http_code}" "$HEALTH_CHECK_URL")
http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | head -n -1)

if [ "$http_code" -eq 200 ]; then
  echo "Success: Health check returned 200 OK"
  echo "Response: $body"
else
  echo "Warning: Health check returned status $http_code"
  echo "Response: $body"
  echo "Make sure the function is deployed and the URL is correct."
fi

echo ""
echo "--- Maintenance Routine Complete ---"
