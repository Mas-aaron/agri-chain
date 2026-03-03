# Huawei BCS Migration Guide

This guide walks you through migrating the AgriChain blockchain features from the current mock implementation to Huawei Blockchain Cloud Service (BCS) after you have created a BCS instance.

## Prerequisites

- Huawei Cloud account with BCS enabled
- Created a BCS Fabric network instance
- Go gateway codebase (this project)
- Flutter app codebase (this project)
- Basic familiarity with Fabric chaincode concepts

---

## 1. Collect BCS Instance Details

After creating your BCS instance on Huawei Cloud, collect the following:

| Item | Where to find | Example |
|------|---------------|---------|
| **BCS Invoke Endpoint** | BCS instance details → API endpoint | `https://bcs.cn-north-4.myhuaweicloud.com/rest/v1/bcs/invoke` |
| **Access Key (AK)** | IAM → Access Management → Access Keys | `ABCDEFGHIJKLMN1234567` |
| **Secret Key (SK)** | IAM → Access Management → Access Keys | `abcdef1234567890abcdef1234567890abcdef12` |
| **Chaincode Name** | BCS instance → Chaincode tab | `agriyield` |
| **Organization/Peer Info** | BCS instance topology | `org1`, `peer0.org1` |

---

## 2. Prepare Chaincode on BCS

Deploy or ensure the following chaincode functions exist on your BCS Fabric network:

### Chaincode Functions Required

| Function | Purpose | Input | Output |
|----------|---------|-------|--------|
| `CreateYieldAsset` | Mint a yield asset | `{farmerId, season, cropType, predictedYield, qualityScore, location, timestamp}` | `{assetId, txId}` |
| `QueryYieldAsset` | Query a single asset | `{assetId}` | Asset JSON |
| `QueryAllYieldAssets` | List all assets | `{}` | Array of assets |

**Sample chaincode stub (Go):**

```go
func (s *SmartContract) CreateYieldAsset(ctx contractapi.TransactionContextInterface, input string) (*YieldAsset, error) {
    var asset YieldAsset
    if err := json.Unmarshal([]byte(input), &asset); err != nil {
        return nil, err
    }
    asset.ID = ctx.GetStub().GetTxID()
    asset.CreatedAt = time.Now().Unix()
    assetBytes, _ := json.Marshal(asset)
    ctx.GetStub().PutState(asset.ID, assetBytes)
    return &asset, nil
}
```

---

## 3. Configure Go Gateway Environment Variables

Create or update `.env` in the `server/` directory:

```bash
# Switch from mock to BCS
BLOCKCHAIN_MODE=bcs

# Huawei BCS connection
BCS_ENDPOINT=https://bcs.cn-north-4.myhuaweicloud.com/rest/v1/bcs/invoke
BCS_ACCESS_KEY=YOUR_ACCESS_KEY
BCS_SECRET_KEY=YOUR_SECRET_KEY
BCS_CHAINCODE_NAME=agriyield

# Optional: Override if your chaincode uses a different name
# BCS_CHAINCODE_NAME=mycc
```

**Security Note:** Never commit `.env` with real keys. Use secret management in production.

---

## 4. Verify BCS Adapter Implementation

The Go gateway already includes a BCS adapter. Ensure it matches your BCS instance:

- File: `server/internal/blockchain/bcs/http_client.go`
- The adapter sends chaincode invoke requests to `BCS_ENDPOINT` with `X-Access-Key` and `X-Secret-Key` headers.
- If your BCS uses a different authentication scheme, update `http_client.go`.

---

## 5. Test BCS Connection

Run the Go gateway locally with BCS config:

```bash
cd server
export BLOCKCHAIN_MODE=bcs
export BCS_ENDPOINT="https://bcs.cn-north-4.myhuaweicloud.com/rest/v1/bcs/invoke"
export BCS_ACCESS_KEY="YOUR_AK"
export BCS_SECRET_KEY="YOUR_SK"
export BCS_CHAINCODE_NAME="agriyield"
go run cmd/main.go
```

Send a test request:

```bash
curl -X POST http://localhost:8000/v1/yield-assets/mint \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <firebase_id_token>" \
  -d '{"farmerId":"test","season":"2025","cropType":"maize","predictedYield":1200,"qualityScore":0.85,"location":"Kenya","timestamp":"2025-02-19T12:00:00Z"}'
```

Expected response:

```json
{
  "assetId": "tx-12345",
  "txId": "tx-12345",
  "message": "Yield asset minted on blockchain"
}
```

---

## 6. Update Flutter (No Changes Required)

The Flutter app already calls the Go gateway `/v1` endpoints. No code changes are needed. Ensure:

- `API_BASE_URL` points to your Go gateway (local or deployed).
- Firebase authentication is working (Admin UI uses it).

---

## 7. Deploy Go Gateway to Production

Deploy the Go gateway with the BCS environment variables set securely (e.g., Kubernetes secrets, ECS env vars, or Huawei Cloud FunctionGraph env vars).

---

## 8. End-to-End Validation Checklist

- [ ] BCS instance is running and chaincode is instantiated.
- [ ] Go gateway starts without errors in `bcs` mode.
- [ ] `POST /v1/yield-assets/mint` returns a valid `assetId`/`txId`.
- [ ] `GET /v1/yield-assets` lists minted assets.
- [ ] Flutter app can mint assets via the app.
- [ ] Admin UI can view blockchain assets.
- [ ] Logs show successful BCS invocations (check Go gateway logs).

---

## 9. Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| 401/403 from BCS | Invalid AK/SK or endpoint | Verify keys and endpoint in Huawei console |
| Chaincode not found | Wrong `BCS_CHAINCODE_NAME` | Set correct chaincode name |
| Timeout | Network/firewall | Ensure gateway can reach BCS endpoint |
| Invalid function name | Chaincode mismatch | Deploy/upgrade chaincode with required functions |

---

## 10. Optional: Enhancements

- **Retry logic:** Add exponential backoff in `bcs/http_client.go` for transient errors.
- **Metrics:** Emit Prometheus counters for BCS invoke success/failure.
- **Batching:** If you need high throughput, implement batch minting via a new chaincode function.

---

## Summary

1. Collect BCS endpoint, AK/SK, and chaincode name.
2. Deploy chaincode with `CreateYieldAsset`/`QueryYieldAsset`.
3. Set Go gateway env vars to `BLOCKCHAIN_MODE=bcs` and BCS keys.
4. Test locally with a sample mint request.
5. Deploy the gateway and verify end-to-end flow.

That’s it—your AgriChain blockchain features will now operate on Huawei BCS instead of the mock implementation.
