class Supplier {
  final String id;
  final String name;
  final String phone;
  final String location;
  final String licenseId;
  final bool isApproved;

  const Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.location,
    required this.licenseId,
    required this.isApproved,
  });

  factory Supplier.fromMap(String id, Map<String, dynamic> data) {
    return Supplier(
      id: id,
      name: (data['name'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      location: (data['location'] as String?) ?? '',
      licenseId: (data['licenseId'] as String?) ?? '',
      isApproved: (data['isApproved'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'location': location,
      'licenseId': licenseId,
      'isApproved': isApproved,
    };
  }
}
