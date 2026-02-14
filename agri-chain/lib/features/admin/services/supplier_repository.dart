import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/supplier.dart';

class SupplierRepository {
  SupplierRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('suppliers');

  Stream<List<Supplier>> watchSuppliers() {
    return _col.orderBy('name').snapshots().map(
          (snap) => snap.docs
              .map((d) => Supplier.fromMap(d.id, d.data()))
              .toList(growable: false),
        );
  }

  Future<void> upsertSupplier(Supplier supplier) async {
    await _col.doc(supplier.id).set(supplier.toMap(), SetOptions(merge: true));
  }

  Future<String> createSupplier({
    required String name,
    required String phone,
    required String location,
    required String licenseId,
    required bool isApproved,
  }) async {
    final doc = _col.doc();
    await doc.set({
      'name': name,
      'phone': phone,
      'location': location,
      'licenseId': licenseId,
      'isApproved': isApproved,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> deleteSupplier(String id) async {
    await _col.doc(id).delete();
  }
}
