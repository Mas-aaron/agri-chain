import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/agrochemical.dart';

class AgrochemicalRepository {
  AgrochemicalRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('agrochemicals');

  Stream<List<Agrochemical>> watchAgrochemicals() {
    return _col.orderBy('name').snapshots().map(
          (snap) => snap.docs
              .map((d) => Agrochemical.fromMap(d.id, d.data()))
              .toList(growable: false),
        );
  }

  Future<String> createAgrochemical({
    required String name,
    required String activeIngredient,
    required String target,
    required String usage,
    required bool isCredited,
    required List<String> approvedSupplierIds,
  }) async {
    final doc = _col.doc();
    await doc.set({
      'name': name,
      'activeIngredient': activeIngredient,
      'target': target,
      'usage': usage,
      'isCredited': isCredited,
      'approvedSupplierIds': approvedSupplierIds,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateAgrochemical(Agrochemical agrochemical) async {
    await _col
        .doc(agrochemical.id)
        .set(agrochemical.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteAgrochemical(String id) async {
    await _col.doc(id).delete();
  }
}
