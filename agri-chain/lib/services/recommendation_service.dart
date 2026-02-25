import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ApprovedSeller {
  final String id;
  final String name;
  final String phone;
  final String location;
  final bool isApproved;
  final String? licenseId;

  const ApprovedSeller({
    required this.id,
    required this.name,
    required this.phone,
    required this.location,
    required this.isApproved,
    this.licenseId,
  });

  factory ApprovedSeller.fromJson(Map<String, dynamic> json, String docId) {
    return ApprovedSeller(
      id: docId,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      location: json['location'] ?? '',
      isApproved: json['isApproved'] ?? true,
      licenseId: json['licenseId'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'location': location,
    'isApproved': isApproved,
    if (licenseId != null) 'licenseId': licenseId,
  };
}

class CreditedAgrochemical {
  final String id;
  final String name;
  final String activeIngredient;
  final String target;
  final String usage;
  final bool isCredited;
  final List<String> approvedSellerIds;

  const CreditedAgrochemical({
    required this.id,
    required this.name,
    required this.activeIngredient,
    required this.target,
    required this.usage,
    required this.isCredited,
    required this.approvedSellerIds,
  });

  factory CreditedAgrochemical.fromJson(Map<String, dynamic> json, String docId) {
    final sellerIds = json['approvedSellerIds'] as List<dynamic>?;
    return CreditedAgrochemical(
      id: docId,
      name: json['name'] ?? '',
      activeIngredient: json['activeIngredient'] ?? '',
      target: json['target'] ?? '',
      usage: json['usage'] ?? '',
      isCredited: json['isCredited'] ?? true,
      approvedSellerIds: sellerIds?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'activeIngredient': activeIngredient,
    'target': target,
    'usage': usage,
    'isCredited': isCredited,
    'approvedSellerIds': approvedSellerIds,
  };
}

class RecommendationResult {
  final String normalizedKey;
  final bool isHealthy;
  final bool isNonMaize;
  final List<CreditedAgrochemical> chemicals;
  final Map<String, List<ApprovedSeller>> sellersByChemicalId;

  const RecommendationResult({
    required this.normalizedKey,
    required this.isHealthy,
    required this.isNonMaize,
    required this.chemicals,
    required this.sellersByChemicalId,
  });
}

class RecommendationService {
  static List<ApprovedSeller> _sellers = [];
  static Map<String, List<CreditedAgrochemical>> _chemicalsByDisease = {};
  static bool _isLoaded = false;

  static Future<void> init() async {
    if (_isLoaded) return;
    await reload();
  }

  static Future<void> reload() async {
    try {
      final sellersSnap = await FirebaseFirestore.instance.collection('agro_sellers').get();
      _sellers = sellersSnap.docs.map((d) => ApprovedSeller.fromJson(d.data(), d.id)).toList();

      final chemSnap = await FirebaseFirestore.instance.collection('agro_chemicals').get();
      final chems = chemSnap.docs.map((d) => CreditedAgrochemical.fromJson(d.data(), d.id)).toList();
      
      _chemicalsByDisease.clear();
      for (final chem in chems) {
        // Assume target holds comma-separated disease keywords
        final targets = chem.target.split(',').map((t) => t.trim().toLowerCase());
        for (final t in targets) {
          if (t.isNotEmpty) {
            final list = _chemicalsByDisease.putIfAbsent(t, () => []);
            list.add(chem);
          }
        }
      }
      
      if (_sellers.isEmpty && _chemicalsByDisease.isEmpty) {
        await seedDefaultsIfEmpty();
      } else {
        _isLoaded = true;
      }
    } catch (e) {
      debugPrint('Error loading recommendations from Firestore: $e');
      _sellers = _defaultSellers;
      _chemicalsByDisease = _defaultChemicalsByDisease;
    }
  }

  static Future<void> seedDefaultsIfEmpty() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('agro_sellers').limit(1).get();
      if (snap.docs.isEmpty) {
        for (final seller in _defaultSellers) {
          await FirebaseFirestore.instance.collection('agro_sellers').doc(seller.id).set(seller.toJson());
        }
        for (final entry in _defaultChemicalsByDisease.entries) {
          for (final chem in entry.value) {
            await FirebaseFirestore.instance.collection('agro_chemicals').doc(chem.id).set(chem.toJson());
          }
        }
        await reload();
      }
    } catch (e) {
      debugPrint('Seed Defaults Error: $e');
      _sellers = _defaultSellers;
      _chemicalsByDisease = _defaultChemicalsByDisease;
    }
  }

  static String normalizeLabel(String label) {
    return label.replaceAll('_', ' ').trim().toLowerCase();
  }

  static bool isHealthyLabel(String normalized) => normalized.contains('healthy');

  static bool isNonMaizeLabel(String normalized) {
    return normalized.contains('not maize') ||
        normalized.contains('negative image') ||
        normalized.contains('negative') ||
        normalized.contains('non maize');
  }

  static RecommendationResult recommendForLabel(String rawLabel) {
    if (!_isLoaded) {
      // Synchronous fallback if init() hasn't completed or offline
      _sellers = _sellers.isEmpty ? _defaultSellers : _sellers;
      _chemicalsByDisease = _chemicalsByDisease.isEmpty ? _defaultChemicalsByDisease : _chemicalsByDisease;
    }

    final normalized = normalizeLabel(rawLabel);
    final healthy = isHealthyLabel(normalized);
    final nonMaize = isNonMaizeLabel(normalized);

    final chemicals = (healthy || nonMaize) ? const <CreditedAgrochemical>[] : _matchChemicals(normalized);

    final sellersByChemicalId = <String, List<ApprovedSeller>>{};
    for (final chem in chemicals) {
      final sellers = _sellers
          .where((s) => s.isApproved && chem.approvedSellerIds.contains(s.id))
          .toList(growable: false);
      sellersByChemicalId[chem.id] = sellers;
    }

    return RecommendationResult(
      normalizedKey: normalized,
      isHealthy: healthy,
      isNonMaize: nonMaize,
      chemicals: chemicals,
      sellersByChemicalId: sellersByChemicalId,
    );
  }

  static List<CreditedAgrochemical> _matchChemicals(String normalizedLabel) {
    for (final entry in _chemicalsByDisease.entries) {
      if (normalizedLabel.contains(entry.key)) {
        return entry.value;
      }
    }
    return const [];
  }

  static const _defaultSellers = <ApprovedSeller>[
    ApprovedSeller(
      id: 'seller_kampala_01',
      name: 'AgroVet Kampala',
      phone: '+256 700 000 001',
      location: 'Kampala',
      isApproved: true,
      licenseId: 'UG-AGRO-AVK-001',
    ),
    ApprovedSeller(
      id: 'seller_mbarara_01',
      name: 'Mbarara Farm Inputs',
      phone: '+256 700 000 002',
      location: 'Mbarara',
      isApproved: true,
      licenseId: 'UG-AGRO-MFI-014',
    ),
    ApprovedSeller(
      id: 'seller_gulu_01',
      name: 'Northern Agro Supplies',
      phone: '+256 700 000 003',
      location: 'Gulu',
      isApproved: true,
      licenseId: 'UG-AGRO-NAS-077',
    ),
    ApprovedSeller(
      id: 'seller_mbale_01',
      name: 'Mt. Elgon Coffee Supplies',
      phone: '+256 700 000 004',
      location: 'Mbale',
      isApproved: true,
      licenseId: 'UG-AGRO-MEC-099',
    ),
  ];

  static const _defaultChemicalsByDisease = <String, List<CreditedAgrochemical>>{
    'blight': [
      CreditedAgrochemical(
        id: 'chem_bl_mancozeb',
        name: 'Mancozeb 80% WP',
        activeIngredient: 'Mancozeb',
        target: 'blight',
        usage: 'Spray as per label; rotate modes of action; avoid overuse.',
        isCredited: true,
        approvedSellerIds: ['seller_kampala_01', 'seller_mbarara_01'],
      ),
      CreditedAgrochemical(
        id: 'chem_bl_azoxystrobin',
        name: 'Azoxystrobin 250 SC',
        activeIngredient: 'Azoxystrobin',
        target: 'blight',
        usage: 'Apply early at first symptoms; follow label rate; observe PHI.',
        isCredited: true,
        approvedSellerIds: ['seller_kampala_01', 'seller_gulu_01'],
      ),
    ],
    'common rust': [
      CreditedAgrochemical(
        id: 'chem_rust_propiconazole',
        name: 'Propiconazole 250 EC',
        activeIngredient: 'Propiconazole',
        target: 'common rust',
        usage: 'Spray at early infection; rotate fungicides; follow label.',
        isCredited: true,
        approvedSellerIds: ['seller_mbarara_01', 'seller_gulu_01'],
      ),
    ],
    'gray leaf spot': [
      CreditedAgrochemical(
        id: 'chem_gls_tebuconazole',
        name: 'Tebuconazole 250 EW',
        activeIngredient: 'Tebuconazole',
        target: 'gray leaf spot, leaf spot',
        usage: 'Apply preventively or at first symptoms; follow label instructions.',
        isCredited: true,
        approvedSellerIds: ['seller_kampala_01', 'seller_mbarara_01'],
      ),
    ],
    'leaf rust': [
      CreditedAgrochemical(
        id: 'chem_coffee_rust_copper',
        name: 'Copper Oxychloride 50 WP',
        activeIngredient: 'Copper Oxychloride',
        target: 'leaf rust, rust',
        usage: 'Apply preventively before rains; spray both sides of the leaf. Do not overuse to avoid copper buildup.',
        isCredited: true,
        approvedSellerIds: ['seller_mbale_01', 'seller_kampala_01'],
      ),
      CreditedAgrochemical(
        id: 'chem_coffee_rust_triadimefon',
        name: 'Triadimefon 25% WP',
        activeIngredient: 'Triadimefon',
        target: 'leaf rust, rust',
        usage: 'Apply at early signs of rust infection; highly systemic; follow specified PHI.',
        isCredited: true,
        approvedSellerIds: ['seller_mbale_01'],
      ),
    ],
    'phoma': [
      CreditedAgrochemical(
        id: 'chem_coffee_phoma_chlorothalonil',
        name: 'Chlorothalonil 720 SC',
        activeIngredient: 'Chlorothalonil',
        target: 'phoma',
        usage: 'Broad-spectrum contact fungicide; apply during cool/wet weather conditions. Ensure thorough coverage.',
        isCredited: true,
        approvedSellerIds: ['seller_mbale_01', 'seller_kampala_01'],
      ),
    ],
  };
}
