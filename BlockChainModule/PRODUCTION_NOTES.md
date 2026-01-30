# Production Notes — Huawei Cloud

## Key Management (Critical)

### Option 1: Huawei KMS (Recommended)

1. In Huawei Cloud Console → KMS, create a new key (symmetric or asymmetric, ECDSA recommended).
2. Note the **Key ID** and generate IAM credentials (access key + secret key).
3. Set environment variables:
   ```bash
   USE_KMS=true
   HUAWEI_KMS_REGION=cn-north-4          # or your region
   HUAWEI_KMS_KEY_ID=your-key-id
   HUAWEI_ACCESS_KEY=your-access-key
   HUAWEI_SECRET_KEY=your-secret-key
   ```
4. The backend will use `KMSSigner` to sign all transactions via KMS API.

### Option 2: PRIVATE_KEY (Development only)

Set `PRIVATE_KEY` env var. **Never commit this to version control.**

## Backend Deployment

Build and push image to Huawei SWR:

```bash
docker build -t <swr-region>.swr.cloud.huaweicloud.com/<namespace>/agritech-backend:latest -f backend/Dockerfile ./backend
docker push <swr-region>.swr.cloud.huaweicloud.com/<namespace>/agritech-backend:latest
```

Then deploy on **Huawei CCE** or **ECS**:
- Use Kubernetes Secrets or Huawei Secret Manager to store KMS/private key credentials.
- Do NOT pass secrets as plaintext environment variables.

## Contract Deployment

1. Set `HUAWEI_RPC_URL` to your Huawei blockchain RPC endpoint.
2. Run the deploy script:
   ```bash
   npm run deploy:huawei
   ```
3. After deployment, save returned contract addresses to `AGRI_*_ADDRESS` env vars.

## Network Configuration

- Ensure `HUAWEI_RPC_URL` points to a valid Ethereum RPC endpoint (managed or self-hosted geth on ECS).
- Configure firewall rules: allow backend to reach RPC endpoint; allow frontend/clients to reach backend API.
- Use VPC for internal communication; expose backend via load balancer (ELB).

## Monitoring & Security

- Set up CloudWatch / AOM (Application Operations Management) for logs and metrics.
- Enable VPC Flow Logs to monitor network traffic.
- Use Huawei WAF for API protection.
- Rotate KMS keys periodically.
- Enable API Gateway rate limiting and IP whitelisting.

