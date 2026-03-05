import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ContractCreateRequest {
  final String crop;
  final double quantityKg;
  final double unitPrice;
  final String currency;
  final String farmerName;
  final String? farmerPhone;
  final String? evidenceHash;

  const ContractCreateRequest({
    this.crop = 'Maize',
    required this.quantityKg,
    required this.unitPrice,
    this.currency = 'UGX',
    required this.farmerName,
    this.farmerPhone,
    this.evidenceHash,
  });

  Map<String, dynamic> toJson() => {
        'crop': crop,
        'quantity_kg': quantityKg,
        'unit_price': unitPrice,
        'currency': currency,
        'farmer_name': farmerName,
        if (farmerPhone != null) 'farmer_phone': farmerPhone,
        if (evidenceHash != null) 'evidence_hash': evidenceHash,
      };
}

class ContractPurchaseRequest {
  final String buyerName;

  const ContractPurchaseRequest({required this.buyerName});

  Map<String, dynamic> toJson() => {
        'buyer_name': buyerName,
      };
}

class ContractDeliverRequest {
  final String actor;
  final String? ref;

  const ContractDeliverRequest({required this.actor, this.ref});

  Map<String, dynamic> toJson() => {
        'actor': actor,
        if (ref != null) 'ref': ref,
      };
}

class YieldContractDto {
  final String id;
  final String crop;
  final double quantityKg;
  final double unitPrice;
  final String currency;
  final String status;
  final String farmerName;
  final String? farmerPhone;
  final String? buyerName;
  final String? evidenceHash;
  final DateTime createdAt;

  const YieldContractDto({
    required this.id,
    required this.crop,
    required this.quantityKg,
    required this.unitPrice,
    required this.currency,
    required this.status,
    required this.farmerName,
    this.farmerPhone,
    required this.buyerName,
    required this.evidenceHash,
    required this.createdAt,
  });

  double get total => quantityKg * unitPrice;

  Map<String, dynamic> toJson() => {
        'id': id,
        'crop': crop,
        'quantity_kg': quantityKg,
        'unit_price': unitPrice,
        'currency': currency,
        'status': status,
        'farmer_name': farmerName,
        if (farmerPhone != null) 'farmer_phone': farmerPhone,
        if (buyerName != null) 'buyer_name': buyerName,
        if (evidenceHash != null) 'evidence_hash': evidenceHash,
        'created_at': createdAt.toIso8601String(),
        'total': total,
      };

  factory YieldContractDto.fromJson(Map<String, dynamic> json) {
    final qtyRaw = json['quantity_kg'];
    final unitRaw = json['unit_price'];
    final createdRaw = json['created_at'];

    return YieldContractDto(
      id: (json['id'] ?? '').toString(),
      crop: (json['crop'] ?? '').toString(),
      quantityKg: qtyRaw is num ? qtyRaw.toDouble() : double.tryParse('$qtyRaw') ?? 0,
      unitPrice: unitRaw is num ? unitRaw.toDouble() : double.tryParse('$unitRaw') ?? 0,
      currency: (json['currency'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      farmerName: (json['farmer_name'] ?? '').toString(),
      farmerPhone: json['farmer_phone'] == null ? null : (json['farmer_phone']).toString(),
      buyerName: json['buyer_name'] == null ? null : (json['buyer_name']).toString(),
      evidenceHash: json['evidence_hash'] == null ? null : (json['evidence_hash']).toString(),
      createdAt: DateTime.tryParse('$createdRaw') ?? DateTime.now(),
    );
  }
}

class LedgerEventDto {
  final String id;
  final DateTime time;
  final String action;
  final String actor;
  final String contractId;
  final Map<String, String> meta;

  const LedgerEventDto({
    required this.id,
    required this.time,
    required this.action,
    required this.actor,
    required this.contractId,
    required this.meta,
  });

  factory LedgerEventDto.fromJson(Map<String, dynamic> json) {
    final tRaw = json['time'];
    final metaRaw = json['meta'];

    final meta = <String, String>{};
    if (metaRaw is Map) {
      for (final e in metaRaw.entries) {
        meta['${e.key}'] = '${e.value}';
      }
    }

    return LedgerEventDto(
      id: (json['id'] ?? '').toString(),
      time: DateTime.tryParse('$tRaw') ?? DateTime.now(),
      action: (json['action'] ?? '').toString(),
      actor: (json['actor'] ?? '').toString(),
      contractId: (json['contract_id'] ?? '').toString(),
      meta: meta,
    );
  }
}

class ContractsApiService {
  final Uri baseUri;

  /// Timeout for all API calls. Android mobile networks can be slow — 15s prevents silent hangs.
  static const _timeout = Duration(seconds: 15);

  const ContractsApiService(this.baseUri);

  Map<String, String> _headers() {
    return <String, String>{
      'Content-Type': 'application/json',
    };
  }

  static Uri _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('baseUrl is empty');
    }
    return Uri.parse(trimmed);
  }

  factory ContractsApiService.fromBaseUrl(String baseUrl) {
    return ContractsApiService(_normalizeBaseUrl(baseUrl));
  }

  Uri _url(String path, {Map<String, String>? query}) {
    return baseUri.replace(
      path: baseUri.path.endsWith('/')
          ? '${baseUri.path}${path.startsWith('/') ? path.substring(1) : path}'
          : '${baseUri.path}${path.startsWith('/') ? path : '/$path'}',
      queryParameters: query,
    );
  }

  /// Extracts a human-readable error from a backend JSON response.
  String _parseError(http.Response resp, String fallback) {
    try {
      final body = jsonDecode(resp.body);
      if (body is Map) {
        return (body['detail'] ?? body['message'] ?? fallback).toString();
      }
    } catch (_) {}
    return '$fallback (${resp.statusCode})';
  }

  Future<List<YieldContractDto>> listContracts({String? status}) async {
    final resp = await http
        .get(
          _url('/contracts', query: status == null ? null : {'status': status}),
          headers: _headers(),
        )
        .timeout(_timeout);

    if (resp.statusCode >= 400) {
      throw Exception(_parseError(resp, 'Failed to load contracts'));
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Invalid contracts response');
    }

    return decoded
        .whereType<Map>()
        .map((e) => YieldContractDto.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<YieldContractDto> createContract(ContractCreateRequest request) async {
    final resp = await http
        .post(
          _url('/contracts'),
          headers: _headers(),
          body: jsonEncode(request.toJson()),
        )
        .timeout(_timeout);

    if (resp.statusCode >= 400) {
      throw Exception(_parseError(resp, 'Failed to create contract'));
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw Exception('Invalid create contract response');
    }

    return YieldContractDto.fromJson(decoded.cast<String, dynamic>());
  }

  Future<YieldContractDto> purchaseContract(String contractId, ContractPurchaseRequest request) async {
    final resp = await http
        .post(
          _url('/contracts/$contractId/purchase'),
          headers: _headers(),
          body: jsonEncode(request.toJson()),
        )
        .timeout(_timeout);

    if (resp.statusCode >= 400) {
      throw Exception(_parseError(resp, 'Failed to purchase contract'));
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw Exception('Invalid purchase response');
    }

    return YieldContractDto.fromJson(decoded.cast<String, dynamic>());
  }

  Future<YieldContractDto> deliverContract(String contractId, ContractDeliverRequest request) async {
    final resp = await http
        .post(
          _url('/contracts/$contractId/deliver'),
          headers: _headers(),
          body: jsonEncode(request.toJson()),
        )
        .timeout(_timeout);

    if (resp.statusCode >= 400) {
      throw Exception(_parseError(resp, 'Failed to deliver contract'));
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw Exception('Invalid deliver response');
    }

    return YieldContractDto.fromJson(decoded.cast<String, dynamic>());
  }

  Future<List<LedgerEventDto>> listLedger({String? contractId, int limit = 100}) async {
    final query = <String, String>{'limit': '$limit'};
    if (contractId != null && contractId.trim().isNotEmpty) {
      query['contract_id'] = contractId.trim();
    }

    final resp = await http
        .get(
          _url('/ledger', query: query),
          headers: _headers(),
        )
        .timeout(_timeout);

    if (resp.statusCode >= 400) {
      throw Exception(_parseError(resp, 'Failed to load ledger'));
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Invalid ledger response');
    }

    return decoded
        .whereType<Map>()
        .map((e) => LedgerEventDto.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }
}
