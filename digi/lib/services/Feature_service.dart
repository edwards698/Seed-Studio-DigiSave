import 'package:cloud_firestore/cloud_firestore.dart';

class FeatureService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _features =
      _firestore.collection('features');

  /// Get all feature states as Map<String, bool> for a given docId
  static Future<Map<String, bool>> getFeatureStates({
    required String docId,
  }) async {
    try {
      final DocumentSnapshot snap = await _features.doc(docId).get();

      if (!snap.exists) {
        return <String, bool>{};
      }

      final Map<String, dynamic> data =
          snap.data() as Map<String, dynamic>? ?? <String, dynamic>{};
      final Map<String, bool> boolMap = <String, bool>{};

      data.forEach((key, value) {
        // Skip timestamp fields
        if (key == 'updatedAt' || key == 'createdAt') return;

        if (value is bool) {
          boolMap[key] = value;
        } else if (value is int) {
          boolMap[key] = value == 1;
        } else if (value is String) {
          boolMap[key] = value.toLowerCase() == 'true';
        } else {
          // Convert any other type to bool
          boolMap[key] = value == true;
        }
      });

      return boolMap;
    } catch (e) {
      print('Error getting feature states: $e');
      return <String, bool>{};
    }
  }

  /// Update any feature's boolean value in features/{docId}
  static Future<void> setFeature({
    required String docId,
    required String featureName,
    required bool value,
  }) async {
    try {
      await _features.doc(docId).set(
        {
          featureName: value,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error setting feature: $e');
      rethrow;
    }
  }

  /// Toggles the `buzz` bool in `features/{docId}` and returns the new value.
  static Future<bool> toggleBuzz({required String docId}) async {
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final DocumentReference ref = _features.doc(docId);
        final DocumentSnapshot snap = await transaction.get(ref);

        final Map<String, dynamic>? data = snap.data() as Map<String, dynamic>?;
        final bool current = (data?['buzz'] as bool?) ?? false;
        final bool next = !current;

        transaction.set(
          ref,
          {
            'buzz': next,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        return next;
      });
    } catch (e) {
      print('Error toggling buzz: $e');
      rethrow;
    }
  }

  /// Force-set buzz to a specific value.
  static Future<void> setBuzz({
    required String docId,
    required bool value,
  }) async {
    try {
      await _features.doc(docId).set(
        {
          'buzz': value,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error setting buzz: $e');
      rethrow;
    }
  }

  /// Get a specific feature value
  static Future<bool> getFeature({
    required String docId,
    required String featureName,
  }) async {
    try {
      final DocumentSnapshot snap = await _features.doc(docId).get();

      if (!snap.exists) {
        return false;
      }

      final Map<String, dynamic>? data = snap.data() as Map<String, dynamic>?;
      final dynamic value = data?[featureName];

      if (value is bool) {
        return value;
      } else if (value is int) {
        return value == 1;
      } else if (value is String) {
        return value.toLowerCase() == 'true';
      } else {
        return value == true;
      }
    } catch (e) {
      print('Error getting feature: $e');
      return false;
    }
  }

  /// Check if a document exists
  static Future<bool> documentExists({required String docId}) async {
    try {
      final DocumentSnapshot snap = await _features.doc(docId).get();
      return snap.exists;
    } catch (e) {
      print('Error checking document existence: $e');
      return false;
    }
  }

  /// Initialize a new feature document with default values
  static Future<void> initializeFeatures({
    required String docId,
    Map<String, bool>? defaultFeatures,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (defaultFeatures != null) {
        data.addAll(defaultFeatures);
      }

      await _features.doc(docId).set(data, SetOptions(merge: true));
    } catch (e) {
      print('Error initializing features: $e');
      rethrow;
    }
  }
}
