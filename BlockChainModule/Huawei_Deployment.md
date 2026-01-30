# Deploying Agri-Blockchain to Huawei Cloud

This guide shows practical options to run your Ethereum-based project on Huawei Cloud. It covers two approaches: using a managed RPC endpoint (if available) or running your own node on an ECS/CCE instance, plus hosting the backend.

## 1) Prepare (local build & artifacts)

- Compile contracts and produce artifacts:

```bash
# from project root
npm install
npm run compile
```

- Ensure deployment script works locally: `npm run deploy` (or `npm run deploy:sepolia`).

## 2) Environment variables (recommended)

Create a `.env` or use Huawei Secret Manager / KMS to store these values:

```
HUAWEI_RPC_URL=https://<your-huawei-rpc-endpoint>
PRIVATE_KEY=0x....               # or use KMS instead of storing this directly
AGRI_YIELD_TOKEN_ADDRESS=       # filled after deploy
AGRI_ASSET_REGISTRY_ADDRESS=
AGRI_LOAN_MARKET_ADDRESS=
ETHERSCAN_API_KEY=              # optional
```

Use `process.env.HUAWEI_RPC_URL` in `hardhat.config.js` to add a `huawei` network (example below).

## 3) Option A — Use Huawei managed blockchain / RPC (recommended when available)

Steps:

1. In the Huawei Cloud Console, create a blockchain instance or an Ethereum-compatible node (if the product is available in your region). Obtain the HTTPS RPC endpoint.
2. Add the endpoint to `HUAWEI_RPC_URL` (or `ETHEREUM_RPC_URL` used by your backend).
3. Add a network entry to `hardhat.config.js`:

```js
// Add to networks in hardhat.config.js
huawei: {
  url: process.env.HUAWEI_RPC_URL || "",
  accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
},
```

4. Deploy with Hardhat:

```bash
npx hardhat run scripts/deploy.js --network huawei
```

Notes:
- If Huawei provides an access key / secret instead of a direct private-key signer, use a server-side signer that integrates with Huawei KMS or fetches keys at runtime.
- After deploying, save the contract addresses to your backend env variables (`AGRI_..._ADDRESS`).

## 4) Option B — Run your own Ethereum node on Huawei ECS/CCE (self-managed)

1. Create an Elastic Cloud Server (ECS) or Container engine instance.
2. Run an Ethereum client (geth) inside Docker for quick setup:

```bash
docker run -d --name geth -p 8545:8545 -v /data/geth:/root/.ethereum ethereum/client-go:stable \
  --http --http.addr 0.0.0.0 --http.port 8545 --http.api eth,net,web3,personal,txpool --http.vhosts='*'
```

3. Use the ECS public/private IP or internal VPC address as `HUAWEI_RPC_URL` (e.g. `http://<ecs-ip>:8545`).
4. Deploy as in Option A.

## 5) Backend hosting (API service)

Recommended: containerize the backend and run on Huawei Cloud Container Engine (CCE) or an ECS instance.

Example `Dockerfile` for `backend`:

```dockerfile
FROM node:18
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "src/index.js"]
```

Build and push to Huawei SWR (SWR repo URI from your account):

```bash
docker build -t <swr-region>.swr.cloud.huaweicloud.com/<your-namespace>/agritech-backend:latest .
docker push <swr-region>.swr.cloud.huaweicloud.com/<your-namespace>/agritech-backend:latest
```

Then create a deployment in CCE or run the container on ECS. Configure environment variables in the deployment (do NOT put `PRIVATE_KEY` in plaintext; use Secret Manager or KMS).

## 6) Key management and security

- Use Huawei KMS or Secret Manager to store private keys and retrieve them at runtime.
- If KMS supports signing operations, prefer KMS-based signing rather than exposing raw private keys.
- Use HTTPS for all RPC/HTTP endpoints, enable firewall rules, and restrict access to your backend and node RPC to trusted IPs.

## 7) Post-deploy steps

1. Update `backend` env vars with deployed contract addresses.
2. Restart backend container / service.
3. Run end-to-end tests against the deployed network (use a test account to mint/test flows).
4. Monitor logs and set up alerts.

## 8) Sample `hardhat.config.js` snippet

```js
require('dotenv').config();
module.exports = {
  networks: {
    huawei: {
      url: process.env.HUAWEI_RPC_URL || '',
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
};
```

## 9) Troubleshooting & tips

- If deploying fails due to gas price or chain configuration, confirm chain parameters (chainId, gas price strategy) with your Huawei RPC provider.
- If you see contract verification errors, use the provider's block explorer (or export ABI & bytecode and use Etherscan-like verification tools if supported).

---

If you want, I can:

- Add the `huawei` network entry to `hardhat.config.js` and a `deploy:huawei` npm script.
- Add the `Dockerfile` to the `backend` folder and a sample `docker-compose.yml`.
- Integrate a KMS-based signer example for the backend.

Tell me which of the above you'd like me to apply next.
