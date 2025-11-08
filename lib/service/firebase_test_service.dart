import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class FirebaseTestService extends GetxService {
  @override
  Future<FirebaseTestService> init() async {
    await fetchStoresPreview();
    return this;
  }

  Future<void> fetchStoresPreview() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('stores')
          .limit(5)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('[FirebaseTestService] stores collection is empty.');
        return;
      }

      for (final doc in snapshot.docs) {
        debugPrint('[FirebaseTestService] ${doc.id}: ${doc.data()}');
      }
    } catch (error, stackTrace) {
      debugPrint('[FirebaseTestService] Failed to fetch stores: $error');
      debugPrint(stackTrace.toString());
    }
  }
}

