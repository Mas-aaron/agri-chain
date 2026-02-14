class Agrochemical {
  final String id;
  final String name;
  final String activeIngredient;
  final String target;
  final String usage;
  final bool isCredited;
  final List<String> approvedSupplierIds;

  const Agrochemical({
    required this.id,
    required this.name,
    required this.activeIngredient,
    required this.target,
    required this.usage,
    required this.isCredited,
    required this.approvedSupplierIds,
  });

  factory Agrochemical.fromMap(String id, Map<String, dynamic> data) {
    return Agrochemical(
      id: id,
      name: (data['name'] as String?) ?? '',
      activeIngredient: (data['activeIngredient'] as String?) ?? '',
      target: (data['target'] as String?) ?? '',
      usage: (data['usage'] as String?) ?? '',
      isCredited: (data['isCredited'] as bool?) ?? true,
      approvedSupplierIds:
          ((data['approvedSupplierIds'] as List?) ?? const [])
              .whereType<String>()
              .toList(growable: false),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'activeIngredient': activeIngredient,
      'target': target,
      'usage': usage,
      'isCredited': isCredited,
      'approvedSupplierIds': approvedSupplierIds,
    };
  }
}
