import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  // Public getter for Firestore instance
  static FirebaseFirestore get firestore => _firestore;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference for features
  static const String _featuresCollection = 'features';

  /// Update a specific feature state in Firebase
  static Future<void> updateFeatureState({
    required String featureName,
    required bool isActive,
    String? roomName,
    String? deviceId,
  }) async {
    try {
      // Create document ID based on device and room (if available)
      String docId = deviceId ?? 'default_device';
      if (roomName != null) {
        docId = '${docId}_${roomName.toLowerCase().replaceAll(' ', '_')}';
      }

      // Get current states from Firestore (if exists)
      DocumentSnapshot doc =
          await _firestore.collection(_featuresCollection).doc(docId).get();
      Map<String, dynamic> currentData =
          doc.exists ? (doc.data() as Map<String, dynamic>) : {};

      // Start with default states
      Map<String, dynamic> updateData = _getDefaultFeatureStates();
      // Merge in current states
      updateData.addAll(currentData);

      // Convert feature name to field name and update the toggled field
      String fieldName = _getFieldName(featureName);
      updateData[fieldName] = isActive;

      // Add metadata
      updateData['timestamp'] = FieldValue.serverTimestamp();
      updateData['lastUpdated'] = DateTime.now().toIso8601String();
      if (roomName != null) {
        updateData['roomName'] = roomName;
      }
      if (deviceId != null) {
        updateData['deviceId'] = deviceId;
      }

      // Update or create document with all fields
      await _firestore
          .collection(_featuresCollection)
          .doc(docId)
          .set(updateData, SetOptions(merge: true));

      print(
          '✅ Feature $featureName updated to $isActive in Firebase (all fields set)');
    } catch (e) {
      print('❌ Error updating feature $featureName: $e');
      throw Exception('Failed to update feature state: $e');
    }
  }

  /// Get all feature states for a specific device/room
  static Future<Map<String, bool>> getFeatureStates({
    String? roomName,
    String? deviceId,
  }) async {
    try {
      // Create document ID
      String docId = deviceId ?? 'default_device';
      if (roomName != null) {
        docId = '${docId}_${roomName.toLowerCase().replaceAll(' ', '_')}';
      }

      DocumentSnapshot doc =
          await _firestore.collection(_featuresCollection).doc(docId).get();

      if (!doc.exists) {
        print('📄 No feature states found for $docId');
        return _getDefaultFeatureStates();
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // Convert all values to bool
      Map<String, bool> featureStates = {};
      data.forEach((key, value) {
        // Skip metadata fields
        if (key == 'timestamp' ||
            key == 'lastUpdated' ||
            key == 'roomName' ||
            key == 'deviceId') return;
        if (value is bool) {
          featureStates[key] = value;
        } else if (value is int) {
          featureStates[key] = value == 1;
        } else if (value is String) {
          featureStates[key] = value.toLowerCase() == 'true';
        } else {
          featureStates[key] = value == true;
        }
      });

      // Ensure all expected features are present
      final defaults = _getDefaultFeatureStates();
      defaults.forEach((key, defValue) {
        featureStates.putIfAbsent(key, () => defValue);
      });

      print('📥 Retrieved feature states from Firebase: $featureStates');
      return featureStates;
    } catch (e) {
      print('❌ Error getting feature states: $e');
      return _getDefaultFeatureStates();
    }
  }

  /// Listen to real-time updates of feature states
  static Stream<Map<String, bool>> listenToFeatureStates({
    String? roomName,
    String? deviceId,
  }) {
    // Create document ID
    String docId = deviceId ?? 'default_device';
    if (roomName != null) {
      docId = '${docId}_${roomName.toLowerCase().replaceAll(' ', '_')}';
    }

    return _firestore
        .collection(_featuresCollection)
        .doc(docId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return _getDefaultFeatureStates();
      }

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      Map<String, bool> featureStates = {};
      featureStates['timeLapse'] = data['timeLapse'] ?? false;
      featureStates['tracking'] = data['tracking'] ?? false;
      featureStates['motionDetection'] = data['motionDetection'] ?? true;
      featureStates['nightMode'] = data['nightMode'] ?? false;
      featureStates['dormancy'] = data['dormancy'] ?? false;
      featureStates['calibration'] = data['calibration'] ?? false;

      return featureStates;
    });
  }

  /// Update multiple features at once
  static Future<void> updateMultipleFeatures({
    required Map<String, bool> features,
    String? roomName,
    String? deviceId,
  }) async {
    try {
      String docId = deviceId ?? 'default_device';
      if (roomName != null) {
        docId = '${docId}_${roomName.toLowerCase().replaceAll(' ', '_')}';
      }

      Map<String, dynamic> updateData = {
        'timestamp': FieldValue.serverTimestamp(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      // Add all feature states
      features.forEach((featureName, isActive) {
        String fieldName = _getFieldName(featureName);
        updateData[fieldName] = isActive;
      });

      // Add metadata
      if (roomName != null) {
        updateData['roomName'] = roomName;
      }
      if (deviceId != null) {
        updateData['deviceId'] = deviceId;
      }

      await _firestore
          .collection(_featuresCollection)
          .doc(docId)
          .set(updateData, SetOptions(merge: true));

      print('✅ Multiple features updated in Firebase');
    } catch (e) {
      print('❌ Error updating multiple features: $e');
      throw Exception('Failed to update multiple features: $e');
    }
  }

  /// Get feature history/logs
  static Future<List<Map<String, dynamic>>> getFeatureHistory({
    String? roomName,
    String? deviceId,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('feature_history')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (deviceId != null) {
        query = query.where('deviceId', isEqualTo: deviceId);
      }

      if (roomName != null) {
        query = query.where('roomName', isEqualTo: roomName);
      }

      QuerySnapshot snapshot = await query.get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error getting feature history: $e');
      return [];
    }
  }

  /// Log feature change to history
  static Future<void> logFeatureChange({
    required String featureName,
    required bool newState,
    required bool previousState,
    String? roomName,
    String? deviceId,
  }) async {
    try {
      await _firestore.collection('feature_history').add({
        'featureName': featureName,
        'newState': newState,
        'previousState': previousState,
        'roomName': roomName,
        'deviceId': deviceId,
        'timestamp': FieldValue.serverTimestamp(),
        'changeTime': DateTime.now().toIso8601String(),
      });

      print(
          '📝 Feature change logged: $featureName $previousState → $newState');
    } catch (e) {
      print('❌ Error logging feature change: $e');
    }
  }

  // Helper methods

  /// Convert display name to field name
  static String _getFieldName(String displayName) {
    switch (displayName) {
      case 'Time lapse':
        return 'timeLapse';
      case 'Track':
        return 'tracking';
      case 'Motion dete...':
        return 'motionDetection';
      case 'Night mode':
        return 'nightMode';
      case 'Dormancy':
        return 'dormancy';
      case 'Calibration':
        return 'calibration';
      default:
        return displayName
            .toLowerCase()
            .replaceAll(' ', '')
            .replaceAll('.', '');
    }
  }

  /// Get default feature states
  static Map<String, bool> _getDefaultFeatureStates() {
    return {
      'timeLapse': false,
      'tracking': false,
      'motionDetection': true,
      'nightMode': false,
      'dormancy': false,
      'calibration': false,
    };
  }

  /// Convert field name back to display name
  static String getDisplayName(String fieldName) {
    switch (fieldName) {
      case 'timeLapse':
        return 'Time lapse';
      case 'tracking':
        return 'Track';
      case 'motionDetection':
        return 'Motion dete...';
      case 'nightMode':
        return 'Night mode';
      case 'dormancy':
        return 'Dormancy';
      case 'calibration':
        return 'Calibration';
      default:
        return fieldName;
    }
  }
}
