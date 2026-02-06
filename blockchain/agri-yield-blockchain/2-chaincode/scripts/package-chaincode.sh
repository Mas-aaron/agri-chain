#!/bin/bash
# File: 2-chaincode/scripts/package-chaincode.sh
# === AGRIYIELD CHAINCODE PACKAGING SCRIPT ===

echo "📦 Packaging AgriYield Chaincode..."

# 1. Navigate to chaincode directory
cd ../go

# 2. Install Go dependencies
echo "🔧 Installing Go dependencies..."
go mod init agri-yield-chaincode 2>/dev/null || true
go get github.com/hyperledger/fabric-contract-api-go@v1.2.0
go mod tidy

# 3. Build chaincode
echo "🏗️  Building chaincode..."
go build -o agri-yield

# 4. Create package structure
echo "📁 Creating package structure..."
mkdir -p package/META-INF/statedb/couchdb/indexes

# 5. Create CouchDB indexes
cat > package/META-INF/statedb/couchdb/indexes/indexAssetByFarmer.json << EOF
{
  "index": {
    "fields": ["farmerId", "createdAt"]
  },
  "ddoc": "indexAssetByFarmer",
  "name": "indexAssetByFarmer",
  "type": "json"
}
EOF

cat > package/META-INF/statedb/couchdb/indexes/indexAssetByStatus.json << EOF
{
  "index": {
    "fields": ["status", "season"]
  },
  "ddoc": "indexAssetByStatus",
  "name": "indexAssetByStatus",
  "type": "json"
}
EOF

cat > package/META-INF/statedb/couchdb/indexes/indexLoanByBank.json << EOF
{
  "index": {
    "fields": ["bankId", "status"]
  },
  "ddoc": "indexLoanByBank",
  "name": "indexLoanByBank",
  "type": "json"
}
EOF

# 6. Copy chaincode files
cp agri_yield.go package/ 2>/dev/null || echo "agri_yield.go not found"
cp go.mod package/
cp go.sum package/ 2>/dev/null || true

# 7. Create metadata file
cat > package/metadata.json << EOF
{
  "type": "golang",
  "label": "agri_yield_chaincode_v1.0",
  "version": "1.0.0",
  "description": "AgriYield Chaincode for tokenizing agricultural yield predictions",
  "author": "AgriYield Platform",
  "license": "Apache-2.0",
  "language": "golang",
  "channel": "yield-channel",
  "organizations": ["FarmerOrg", "BankOrg", "ExchangeOrg"],
  "endorsementPolicy": {
    "identities": [
      {
        "role": {
          "name": "member",
          "mspId": "FarmerOrgMSP"
        }
      },
      {
        "role": {
          "name": "member",
          "mspId": "BankOrgMSP"
        }
      }
    ],
    "policy": {
      "2-of": [
        {"signed-by": 0},
        {"signed-by": 1}
      ]
    }
  }
}
EOF

# 8. Zip the package
echo "📦 Creating chaincode package..."
cd package
zip -r ../../agri-yield-chaincode-v1.0.zip . 2>/dev/null
cd ..

echo ""
echo "🎉 Chaincode packaged successfully!"
echo "📦 Package: agri-yield-chaincode-v1.0.zip"
echo ""
echo "To deploy:"
echo "1. Upload package to Huawei BCS console"
echo "2. Or use: hwcloud bcs chaincode install --instance-id <id> --chaincode-file agri-yield-chaincode-v1.0.zip"
