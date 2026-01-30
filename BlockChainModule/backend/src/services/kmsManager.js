/**
 * Huawei Cloud KMS-based Signer for Ethereum transactions
 * 
 * Supports signing transactions using Huawei KMS (Key Management Service)
 * with fallback to PRIVATE_KEY for development.
 * 
 * Usage:
 *   const signer = new KMSSigner(provider, {
 *     useKMS: true,
 *     region: 'cn-north-4',
 *     keyId: 'your-key-id',
 *     accessKey: 'your-access-key',
 *     secretKey: 'your-secret-key'
 *   });
 */

const { ethers } = require('ethers');
const crypto = require('crypto');
const https = require('https');

class KMSSigner extends ethers.AbstractSigner {
  constructor(provider, options = {}) {
    super(provider);
    this.useKMS = options.useKMS || false;
    this.region = options.region || 'cn-north-4';
    this.keyId = options.keyId || null;
    this.accessKey = options.accessKey || null;
    this.secretKey = options.secretKey || null;
    this.address = null;

    // Fallback to private key for development
    if (!this.useKMS) {
      const pk = process.env.PRIVATE_KEY || '';
      if (!pk || pk === 'your_private_key_here') {
        throw new Error('PRIVATE_KEY not configured. Set PRIVATE_KEY env var or useKMS=true.');
      }
      this.wallet = new ethers.Wallet(pk, provider);
      this.address = this.wallet.address;
    } else {
      if (!this.keyId || !this.accessKey || !this.secretKey) {
        throw new Error('KMS options missing: keyId, accessKey, secretKey required when useKMS=true.');
      }
    }
  }

  /**
   * Get the signer's Ethereum address
   * For KMS signers, this is derived from the KMS key's public key
   */
  async getAddress() {
    if (this.address) return this.address;

    if (!this.useKMS) {
      return this.wallet.address;
    }

    // For production: derive address from KMS public key
    // This requires fetching the public key from KMS
    console.warn('⚠️  KMS signer address derivation not yet implemented.');
    throw new Error('Implement getPublicKey() call to Huawei KMS to derive address.');
  }

  /**
   * Sign a message using KMS
   */
  async signMessage(message) {
    if (!this.useKMS) {
      return this.wallet.signMessage(message);
    }

    const messageHash = ethers.id(message);
    return this._signWithKMS(messageHash);
  }

  /**
   * Sign a transaction using KMS
   */
  async signTransaction(tx) {
    if (!this.useKMS) {
      return this.wallet.signTransaction(tx);
    }

    // Serialize transaction for signing
    const txData = ethers.Transaction.from(tx);
    const unsignedTx = txData.unsignedSerialized;
    const txHash = ethers.keccak256(unsignedTx);

    // Sign with KMS
    const signature = await this._signWithKMS(txHash);

    // Apply signature to transaction
    txData.signature = signature;
    return txData.serialized;
  }

  /**
   * Internal: call Huawei KMS sign API
   * @private
   */
  async _signWithKMS(dataHash) {
    const kmsEndpoint = `kms.${this.region}.myhuaweicloud.com`;
    
    // Prepare KMS sign request
    const requestBody = {
      key_id: this.keyId,
      signing_algorithm: 'ECDSA_SHA256',
      message_digest: dataHash.slice(2), // Remove 0x prefix
    };

    // Sign the request with AWS Signature V4 (Huawei uses compatible signing)
    const signature = this._signRequest('POST', '/v1.0/sign', requestBody);

    return new Promise((resolve, reject) => {
      const options = {
        hostname: kmsEndpoint,
        port: 443,
        path: '/v1.0/sign',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': signature,
          'X-Sdk-Date': new Date().toISOString(),
        },
      };

      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          try {
            const resp = JSON.parse(data);
            if (resp.signature) {
              resolve('0x' + resp.signature);
            } else {
              reject(new Error('KMS sign response missing signature: ' + data));
            }
          } catch (e) {
            reject(new Error('KMS sign response parse error: ' + e.message));
          }
        });
      });

      req.on('error', reject);
      req.write(JSON.stringify(requestBody));
      req.end();
    });
  }

  /**
   * Internal: sign the KMS HTTP request (AWS Signature V4 compatible)
   * @private
   */
  _signRequest(method, path, body) {
    const timestamp = new Date().toISOString();
    const datestamp = timestamp.slice(0, 10);
    const algorithm = 'AWS4-HMAC-SHA256';
    const service = 'kms';
    const region = this.region;
    const credentialScope = `${datestamp}/${region}/${service}/aws4_request`;

    // Canonical request
    const canonicalRequest = [
      method,
      path,
      '',
      `host:kms.${region}.myhuaweicloud.com`,
      `x-amz-date:${timestamp}`,
      '',
      'host;x-amz-date',
      this._hashPayload(JSON.stringify(body)),
    ].join('\n');

    const canonicalRequestHash = this._hash(canonicalRequest);

    // String to sign
    const stringToSign = [
      algorithm,
      timestamp,
      credentialScope,
      canonicalRequestHash,
    ].join('\n');

    // Calculate signature
    const kDate = this._hmac(`AWS4${this.secretKey}`, datestamp);
    const kRegion = this._hmac(kDate, region);
    const kService = this._hmac(kRegion, service);
    const kSigning = this._hmac(kService, 'aws4_request');
    const signature = this._hmac(kSigning, stringToSign).toString('hex');

    return `${algorithm} Credential=${this.accessKey}/${credentialScope}, SignedHeaders=host;x-amz-date, Signature=${signature}`;
  }

  /**
   * @private
   */
  _hash(data) {
    return crypto.createHash('sha256').update(data).digest('hex');
  }

  /**
   * @private
   */
  _hashPayload(data) {
    return this._hash(data);
  }

  /**
   * @private
   */
  _hmac(key, data) {
    const keyBuffer = typeof key === 'string' ? Buffer.from(key) : key;
    return crypto.createHmac('sha256', keyBuffer).update(data).digest();
  }

  /**
   * Connect to a new provider (for chaining)
   */
  connect(provider) {
    return new KMSSigner(provider, {
      useKMS: this.useKMS,
      region: this.region,
      keyId: this.keyId,
      accessKey: this.accessKey,
      secretKey: this.secretKey,
    });
  }
}

module.exports = KMSSigner;
