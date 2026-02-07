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

  static const _sellers = <ApprovedSeller>[
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
  ];

  static const _chemicalsByDisease = <String, List<CreditedAgrochemical>>{
    'blight': [
      CreditedAgrochemical(
        id: 'chem_bl_mancozeb',
        name: 'Mancozeb 80% WP',
        activeIngredient: 'Mancozeb',
        target: 'Maize leaf blight',
        usage: 'Spray as per label; rotate modes of action; avoid overuse.',
        isCredited: true,
        approvedSellerIds: ['seller_kampala_01', 'seller_mbarara_01'],
      ),
      CreditedAgrochemical(
        id: 'chem_bl_azoxystrobin',
        name: 'Azoxystrobin 250 SC',
        activeIngredient: 'Azoxystrobin',
        target: 'Leaf diseases including blights',
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
        target: 'Common rust',
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
        target: 'Gray leaf spot',
        usage: 'Apply preventively or at first symptoms; follow label instructions.',
        isCredited: true,
        approvedSellerIds: ['seller_kampala_01', 'seller_mbarara_01'],
      ),
    ],
  };

  static RecommendationResult recommendForLabel(String rawLabel) {
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
}
