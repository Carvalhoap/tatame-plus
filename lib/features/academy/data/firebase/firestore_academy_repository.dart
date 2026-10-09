import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/academy.dart';
import '../../repository/academy_repository.dart';

class FirestoreAcademyRepository implements AcademyRepository {
  final FirebaseFirestore firestore;

  FirestoreAcademyRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Academy?> getAcademyById({required String academyId}) async {
    final snapshot = await firestore
        .collection('academies')
        .doc(academyId)
        .get();

    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    String text(String field) {
      return (data[field] as String? ?? '').trim();
    }

    return Academy(
      id: snapshot.id,
      name: text('name'),
      brand: text('brand'),
      city: text('city'),
      state: text('state'),
      phone: text('phone'),
      email: text('email'),
    );
  }
}
