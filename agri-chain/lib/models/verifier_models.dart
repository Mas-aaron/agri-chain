// Models for the Independent Verifier subsystem.

class Verifier {
  final int id;
  final String userId;
  final String organizationName;
  final String organizationType;
  final double stakeAmount;
  final int reputationScore;
  final int totalSubmissions;
  final double accuracyRate;
  final String? apiEndpoint;
  final String? publicKey;
  final bool isActive;
  final String createdAt;
  final String? lastActive;

  Verifier({
    required this.id,
    required this.userId,
    required this.organizationName,
    required this.organizationType,
    required this.stakeAmount,
    required this.reputationScore,
    required this.totalSubmissions,
    required this.accuracyRate,
    this.apiEndpoint,
    this.publicKey,
    required this.isActive,
    required this.createdAt,
    this.lastActive,
  });

  factory Verifier.fromJson(Map<String, dynamic> json) => Verifier(
        id: json['id'] as int,
        userId: json['user_id'] as String,
        organizationName: json['organization_name'] as String,
        organizationType: json['organization_type'] as String,
        stakeAmount: (json['stake_amount'] as num).toDouble(),
        reputationScore: json['reputation_score'] as int,
        totalSubmissions: json['total_submissions'] as int,
        accuracyRate: (json['accuracy_rate'] as num).toDouble(),
        apiEndpoint: json['api_endpoint'] as String?,
        publicKey: json['public_key'] as String?,
        isActive: json['is_active'] == 1 || json['is_active'] == true,
        createdAt: json['created_at'] as String,
        lastActive: json['last_active'] as String?,
      );
}

class OracleSubmission {
  final int id;
  final String assetId;
  final int verifierId;
  final double submittedYield;
  final double confidence;
  final String dataSource;
  final String? measurementMethod;
  final String? notes;
  final String status;
  final String createdAt;

  OracleSubmission({
    required this.id,
    required this.assetId,
    required this.verifierId,
    required this.submittedYield,
    required this.confidence,
    required this.dataSource,
    this.measurementMethod,
    this.notes,
    required this.status,
    required this.createdAt,
  });

  factory OracleSubmission.fromJson(Map<String, dynamic> json) =>
      OracleSubmission(
        id: json['id'] as int,
        assetId: json['asset_id'] as String,
        verifierId: json['verifier_id'] as int,
        submittedYield: (json['submitted_yield'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
        dataSource: json['data_source'] as String,
        measurementMethod: json['measurement_method'] as String?,
        notes: json['notes'] as String?,
        status: json['status'] as String,
        createdAt: json['created_at'] as String,
      );
}

class ConsensusReport {
  final int id;
  final String assetId;
  final double consensusYield;
  final double confidence;
  final int submissionCount;
  final String ipfsHash;
  final List<dynamic> sources;
  final bool appliedToBlockchain;
  final String createdAt;

  ConsensusReport({
    required this.id,
    required this.assetId,
    required this.consensusYield,
    required this.confidence,
    required this.submissionCount,
    required this.ipfsHash,
    required this.sources,
    required this.appliedToBlockchain,
    required this.createdAt,
  });

  factory ConsensusReport.fromJson(Map<String, dynamic> json) =>
      ConsensusReport(
        id: json['id'] as int,
        assetId: json['asset_id'] as String,
        consensusYield: (json['consensus_yield'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
        submissionCount: json['submission_count'] as int,
        ipfsHash: json['ipfs_hash'] as String,
        sources: json['sources'] as List<dynamic>? ?? [],
        appliedToBlockchain:
            json['applied_to_blockchain'] == 1 || json['applied_to_blockchain'] == true,
        createdAt: json['created_at'] as String,
      );
}

class VerifierReward {
  final int id;
  final int verifierId;
  final double amount;
  final String reason;
  final String createdAt;

  VerifierReward({
    required this.id,
    required this.verifierId,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  factory VerifierReward.fromJson(Map<String, dynamic> json) => VerifierReward(
        id: json['id'] as int,
        verifierId: json['verifier_id'] as int,
        amount: (json['amount'] as num).toDouble(),
        reason: json['reason'] as String,
        createdAt: json['created_at'] as String,
      );
}
