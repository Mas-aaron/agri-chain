/// YieldAsset model for blockchain-based agricultural yield tokenization
class YieldAsset {
  final String assetId;
  final String tokenId;
  final String farmerId;
  final String cropType;
  final int season;
  final double predictedYield;
  final double confidence;
  final double tokenAmount;
  final double currentValue;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  YieldAsset({
    required this.assetId,
    required this.tokenId,
    required this.farmerId,
    required this.cropType,
    required this.season,
    required this.predictedYield,
    required this.confidence,
    required this.tokenAmount,
    required this.currentValue,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory YieldAsset.fromJson(Map<String, dynamic> json) {
    return YieldAsset(
      assetId: json['assetId'] as String? ?? '',
      tokenId: json['tokenId'] as String? ?? '',
      farmerId: json['farmerId'] as String? ?? '',
      cropType: json['cropType'] as String? ?? 'Unknown',
      season: json['season'] as int? ?? 0,
      predictedYield: (json['predictedYield'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      tokenAmount: (json['tokenAmount'] as num?)?.toDouble() ?? 0.0,
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assetId': assetId,
      'tokenId': tokenId,
      'farmerId': farmerId,
      'cropType': cropType,
      'season': season,
      'predictedYield': predictedYield,
      'confidence': confidence,
      'tokenAmount': tokenAmount,
      'currentValue': currentValue,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy of YieldAsset with modified fields
  YieldAsset copyWith({
    String? assetId,
    String? tokenId,
    String? farmerId,
    String? cropType,
    int? season,
    double? predictedYield,
    double? confidence,
    double? tokenAmount,
    double? currentValue,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return YieldAsset(
      assetId: assetId ?? this.assetId,
      tokenId: tokenId ?? this.tokenId,
      farmerId: farmerId ?? this.farmerId,
      cropType: cropType ?? this.cropType,
      season: season ?? this.season,
      predictedYield: predictedYield ?? this.predictedYield,
      confidence: confidence ?? this.confidence,
      tokenAmount: tokenAmount ?? this.tokenAmount,
      currentValue: currentValue ?? this.currentValue,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
