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
  });

  factory YieldAsset.fromJson(Map<String, dynamic> json) {
    return YieldAsset(
      assetId: json['assetId'] as String,
      tokenId: json['tokenId'] as String,
      farmerId: json['farmerId'] as String,
      cropType: json['cropType'] as String,
      season: json['season'] as int,
      predictedYield: (json['predictedYield'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      tokenAmount: (json['tokenAmount'] as num).toDouble(),
      currentValue: (json['currentValue'] as num).toDouble(),
      status: json['status'] as String,
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
    };
  }
}
