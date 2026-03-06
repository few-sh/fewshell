# Deploying decamp-relay to GCP

This document describes the steps to deploy the fewshell-relay push notification service to Google Cloud Platform.

## TL;DR - Updating the Service:

To deploy a new version:

```bash
cd decamp-relay

# Rebuild and push
gcloud builds submit \
  --tag us-central1-docker.pkg.dev/few-sh/cloud-run-source-deploy/fewshell-relay:latest \
  --project=few-sh

# Deploy new revision
gcloud run deploy fewshell-relay \
  --image us-central1-docker.pkg.dev/few-sh/cloud-run-source-deploy/fewshell-relay:latest \
  --region us-central1 \
  --project=few-sh
```

## Prerequisites

- `gcloud` CLI installed and authenticated
- Docker (for local testing)
- Access to the `few-sh` GCP project

## Architecture

```
Client → Load Balancer (HTTPS) → Cloud Armor → Cloud Run (private)
              ↓
         SSL Certificate (Google-managed)
              ↓
         relay.fewshell.com (DNS on Cloudflare)
```

**Protection layers:**
- Google-managed SSL certificate
- Cloud Armor with XSS protection and rate limiting (10 req/min per IP)
- API key authentication in the application

## 1. Enable Required APIs

```bash
gcloud services enable \
  secretmanager.googleapis.com \
  run.googleapis.com \
  compute.googleapis.com \
  --project=few-sh
```

## 2. Create Secrets in Secret Manager

### APNs Key (for Apple Push Notifications)

```bash
# Create the secret
gcloud secrets create fewshell-relay-apns-key-sandbox \
  --replication-policy="automatic" \
  --project=few-sh

# Upload the key file
gcloud secrets versions add fewshell-relay-apns-key-sandbox \
  --data-file=keys/AuthKey_7D9KRL9925.p8 \
  --project=few-sh

# Grant access to Cloud Run service account
gcloud secrets add-iam-policy-binding fewshell-relay-apns-key-sandbox \
  --member="serviceAccount:734417761966-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=few-sh
```

### API Key (for client authentication)

```bash
# Generate a random API key
openssl rand -base64 32
# Output: <YOUR_API_KEY>

# Store in Secret Manager
echo -n "YOUR_API_KEY_HERE" | gcloud secrets create fewshell-relay-api-key \
  --data-file=- \
  --replication-policy="automatic" \
  --project=few-sh

# Grant access to Cloud Run service account
gcloud secrets add-iam-policy-binding fewshell-relay-api-key \
  --member="serviceAccount:734417761966-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=few-sh
```

## 3. Build and Push Docker Image

```bash
cd decamp-relay

# Build and push using Cloud Build
gcloud builds submit \
  --tag us-central1-docker.pkg.dev/few-sh/cloud-run-source-deploy/fewshell-relay:latest \
  --project=few-sh
```

## 4. Deploy to Cloud Run

```bash
gcloud run deploy fewshell-relay \
  --image us-central1-docker.pkg.dev/few-sh/cloud-run-source-deploy/fewshell-relay:latest \
  --region us-central1 \
  --platform managed \
  --port 8080 \
  --max-instances=1 \
  --set-secrets="/keys/AuthKey.p8=fewshell-relay-apns-key-sandbox:latest,API_KEY=fewshell-relay-api-key:latest" \
  --set-env-vars="APNS_KEY_PATH=/keys/AuthKey.p8,APNS_KEY_ID=7D9KRL9925,APNS_TEAM_ID=3DLR98CDX9,APNS_BUNDLE_ID=sh.few.fewshell,APNS_USE_SANDBOX=true,RUST_LOG=decamp_relay=info" \
  --project=few-sh
```

Note: Do not add `--allow-unauthenticated` - the service will be accessed through the Load Balancer.

## 5. Set Up Load Balancer

### Create Serverless NEG (Network Endpoint Group)

```bash
gcloud compute network-endpoint-groups create fewshell-relay-neg \
  --region=us-central1 \
  --network-endpoint-type=serverless \
  --cloud-run-service=fewshell-relay \
  --project=few-sh
```

### Create Backend Service

```bash
# Note: Use HTTPS protocol - Cloud Run requires HTTPS for backend communication
gcloud compute backend-services create fewshell-relay-backend \
  --load-balancing-scheme=EXTERNAL_MANAGED \
  --protocol=HTTPS \
  --global \
  --project=few-sh

gcloud compute backend-services add-backend fewshell-relay-backend \
  --global \
  --network-endpoint-group=fewshell-relay-neg \
  --network-endpoint-group-region=us-central1 \
  --project=few-sh
```

### Create URL Map

```bash
gcloud compute url-maps create fewshell-relay-urlmap \
  --default-service=fewshell-relay-backend \
  --global \
  --project=few-sh
```

### Create SSL Certificate (Google-managed)

```bash
gcloud compute ssl-certificates create fewshell-relay-cert \
  --domains=relay.fewshell.com \
  --global \
  --project=few-sh
```

### Create HTTPS Proxy

```bash
gcloud compute target-https-proxies create fewshell-relay-https-proxy \
  --ssl-certificates=fewshell-relay-cert \
  --url-map=fewshell-relay-urlmap \
  --global \
  --project=few-sh
```

### Reserve Static IP Address

```bash
gcloud compute addresses create fewshell-relay-ip \
  --ip-version=IPV4 \
  --global \
  --project=few-sh

# Get the IP address
gcloud compute addresses describe fewshell-relay-ip \
  --global \
  --project=few-sh \
  --format="value(address)"
# Output: 34.149.101.49
```

### Create Forwarding Rule

```bash
gcloud compute forwarding-rules create fewshell-relay-https-rule \
  --load-balancing-scheme=EXTERNAL_MANAGED \
  --network-tier=PREMIUM \
  --address=fewshell-relay-ip \
  --target-https-proxy=fewshell-relay-https-proxy \
  --ports=443 \
  --global \
  --project=few-sh
```

## 6. Allow Public Access to Cloud Run

The Load Balancer needs to invoke Cloud Run. Grant `allUsers` access:

```bash
gcloud run services add-iam-policy-binding fewshell-relay \
  --region=us-central1 \
  --member=allUsers \
  --role=roles/run.invoker \
  --project=few-sh
```

> **Note:** If this fails due to organization policy restrictions, you may need to
> update the `iam.allowedPolicyMemberDomains` policy at the project or org level.

## 7. Configure DNS and SSL Certificate

Add an A record in your DNS provider (Cloudflare):

```
relay.fewshell.com  A  34.149.101.49
```

### Temporary HTTP Setup for SSL Provisioning

Google's SSL certificate provisioning requires HTTP access to validate the domain.
Create a temporary HTTP forwarding rule:

```bash
# Create HTTP proxy
gcloud compute target-http-proxies create fewshell-relay-http-proxy \
  --url-map=fewshell-relay-urlmap \
  --global \
  --project=few-sh

# Create HTTP forwarding rule
gcloud compute forwarding-rules create fewshell-relay-http-rule \
  --load-balancing-scheme=EXTERNAL_MANAGED \
  --network-tier=PREMIUM \
  --address=fewshell-relay-ip \
  --target-http-proxy=fewshell-relay-http-proxy \
  --ports=80 \
  --global \
  --project=few-sh
```

### Wait for SSL Certificate Provisioning

The SSL certificate will provision once DNS propagates (15-30 minutes).

Check certificate status:
```bash
gcloud compute ssl-certificates describe fewshell-relay-cert \
  --global \
  --project=few-sh \
  --format="yaml(managed.status,managed.domainStatus)"
```

Wait until status shows `ACTIVE`.

### Remove HTTP Access (Security)

Once SSL is active, remove HTTP access to enforce HTTPS-only:

```bash
gcloud compute forwarding-rules delete fewshell-relay-http-rule \
  --global --project=few-sh --quiet

gcloud compute target-http-proxies delete fewshell-relay-http-proxy \
  --global --project=few-sh --quiet
```

## 8. Set Up Cloud Armor (DDoS Protection)

### Create Security Policy

```bash
gcloud compute security-policies create fewshell-relay-armor \
  --description="Cloud Armor policy for fewshell-relay" \
  --project=few-sh
```

### Add XSS Protection Rule

```bash
gcloud compute security-policies rules create 1000 \
  --security-policy=fewshell-relay-armor \
  --expression="evaluatePreconfiguredExpr('xss-v33-stable')" \
  --action=deny-403 \
  --description="Block XSS attacks" \
  --project=few-sh
```

### Add Rate Limiting Rule

```bash
gcloud compute security-policies rules create 2000 \
  --security-policy=fewshell-relay-armor \
  --expression="true" \
  --action=throttle \
  --rate-limit-threshold-count=10 \
  --rate-limit-threshold-interval-sec=60 \
  --conform-action=allow \
  --exceed-action=deny-429 \
  --enforce-on-key=IP \
  --description="Rate limit 10 requests per minute per IP" \
  --project=few-sh
```

### Attach Policy to Backend Service

```bash
gcloud compute backend-services update fewshell-relay-backend \
  --security-policy=fewshell-relay-armor \
  --global \
  --project=few-sh
```

## 9. Testing

### Test health endpoint (no auth required)

```bash
curl https://relay.fewshell.com/health
# Output: OK
```

### Test send endpoint (auth required)

```bash
curl -X POST https://relay.fewshell.com/send \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "device_tokens": ["your-device-token"],
    "title": "Test",
    "body": "Hello from fewshell-relay!"
  }'
```

## Cost Estimate

- **Cloud Run**: Pay per use (likely < $5/month for low traffic)
- **Load Balancer**: ~$18/month (fixed cost for global LB)
- **Cloud Armor**: Standard tier is free for basic rules
- **Secret Manager**: < $1/month

## Cleanup (if needed)

```bash
# Delete in reverse order
gcloud compute forwarding-rules delete fewshell-relay-https-rule --global --project=few-sh --quiet
gcloud compute target-https-proxies delete fewshell-relay-https-proxy --global --project=few-sh --quiet
gcloud compute ssl-certificates delete fewshell-relay-cert --global --project=few-sh --quiet
gcloud compute url-maps delete fewshell-relay-urlmap --global --project=few-sh --quiet
gcloud compute backend-services delete fewshell-relay-backend --global --project=few-sh --quiet
gcloud compute network-endpoint-groups delete fewshell-relay-neg --region=us-central1 --project=few-sh --quiet
gcloud compute addresses delete fewshell-relay-ip --global --project=few-sh --quiet
gcloud compute security-policies delete fewshell-relay-armor --project=few-sh --quiet
gcloud run services delete fewshell-relay --region=us-central1 --project=few-sh --quiet
```
