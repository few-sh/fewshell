#!/bin/bash
set -e
# Rebuild and push
gcloud builds submit \
  --tag us-central1-docker.pkg.dev/few-sh/cloud-run-source-deploy/fewshell-relay:latest \
  --project=few-sh

# Deploy new revision
gcloud run deploy fewshell-relay \
  --image us-central1-docker.pkg.dev/few-sh/cloud-run-source-deploy/fewshell-relay:latest \
  --region us-central1 \
  --project=few-sh
