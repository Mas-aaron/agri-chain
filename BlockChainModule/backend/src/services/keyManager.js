const { ethers } = require('ethers');
const KMSSigner = require('./kmsManager');

function getProvider() {
  const url = process.env.ETHEREUM_RPC_URL || process.env.HUAWEI_RPC_URL || 'http://127.0.0.1:8545';
  return new ethers.JsonRpcProvider(url);
}

function getAdminSigner() {
  const provider = getProvider();

  // Option 1: Use Huawei KMS (production recommended)
  if (process.env.USE_KMS === 'true') {
    return new KMSSigner(provider, {
      useKMS: true,
      region: process.env.HUAWEI_KMS_REGION || 'cn-north-4',
      keyId: process.env.HUAWEI_KMS_KEY_ID,
      accessKey: process.env.HUAWEI_ACCESS_KEY,
      secretKey: process.env.HUAWEI_SECRET_KEY,
    });
  }

  // Option 2: Use PRIVATE_KEY from environment (development fallback)
  if (process.env.PRIVATE_KEY && process.env.PRIVATE_KEY !== 'your_private_key_here') {
    return new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  }

  throw new Error(
    'No signer configured. Either set:\n' +
    '  USE_KMS=true + HUAWEI_KMS_REGION + HUAWEI_KMS_KEY_ID + HUAWEI_ACCESS_KEY + HUAWEI_SECRET_KEY\n' +
    '  OR PRIVATE_KEY (development only)'
  );
}

module.exports = { getProvider, getAdminSigner };
