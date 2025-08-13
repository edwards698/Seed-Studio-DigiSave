# Firebase Features Integration

This implementation adds Firebase Firestore integration to track and sync security camera feature states across devices.

## Features Added

### 1. Firebase Service (`lib/services/firebase_service.dart`)

- **updateFeatureState()**: Updates a specific feature state in Firebase
- **getFeatureStates()**: Retrieves all feature states for a device/room
- **listenToFeatureStates()**: Real-time updates of feature states
- **updateMultipleFeatures()**: Batch update multiple features
- **getFeatureHistory()**: Get change history/logs
- **logFeatureChange()**: Log feature changes for audit trail

### 2. Updated Security Screen

- All feature buttons now sync with Firebase
- Features are loaded from Firebase when the screen opens
- Room changes reload features for that specific room
- Loading indicators show when updating Firebase
- Success/error messages for user feedback
- History button to view feature change logs

### 3. Feature History Screen (`lib/screens/feature_history_screen.dart`)

- View all feature changes with timestamps
- Filter by room and device
- Shows previous vs new state
- Time-ago formatting (e.g., "2h ago", "Just now")

## Tracked Features

1. **Time lapse** - Video recording feature
2. **Track** - Object tracking
3. **Motion detection** - Motion sensor alerts
4. **Night mode** - Low-light camera mode
5. **Dormancy** - Power saving mode
6. **Calibration** - Camera calibration settings

## Firebase Structure

### Collection: `features`

Documents are named: `{deviceId}_{roomName}`

```json
{
  "deviceId": "xiao_esp32s3",
  "roomName": "Bedroom",
  "timeLapse": false,
  "tracking": true,
  "motionDetection": true,
  "nightMode": false,
  "dormancy": false,
  "calibration": false,
  "timestamp": "2025-08-12T10:30:00Z",
  "lastUpdated": "2025-08-12T10:30:00.000Z"
}
```

### Collection: `feature_history`

Change logs with timestamps:

```json
{
  "featureName": "Motion dete...",
  "newState": true,
  "previousState": false,
  "roomName": "Bedroom",
  "deviceId": "xiao_esp32s3",
  "timestamp": "2025-08-12T10:30:00Z",
  "changeTime": "2025-08-12T10:30:00.000Z"
}
```

## Setup Instructions

### 1. Firebase Setup

1. Create a Firebase project at https://console.firebase.google.com
2. Enable Firestore Database
3. Add your Flutter app to the Firebase project
4. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
5. Place files in appropriate directories

### 2. Dependencies

Make sure these are in your `pubspec.yaml`:

```yaml
dependencies:
  cloud_firestore: ^4.13.6
  firebase_core: ^2.24.2
  google_fonts: ^6.1.0
  http: ^1.1.0
```

### 3. Firebase Rules

Set up Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write access to features collection
    match /features/{document} {
      allow read, write: if true; // Customize based on your auth needs
    }

    // Allow read/write access to feature_history collection
    match /feature_history/{document} {
      allow read, write: if true; // Customize based on your auth needs
    }
  }
}
```

### 4. Initialize Firebase

In your `main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}
```

## Usage

### Button Interactions

- Tap any feature button to toggle ON/OFF
- State immediately updates in UI
- Firebase sync happens in background
- Success/error messages show sync status

### Room Changes

- Select different room from dropdown
- Features automatically reload for that room
- Each room has independent feature states

### View History

- Tap history icon in header
- See all feature changes with timestamps
- Filter by current room and device

## Error Handling

- Network errors show user-friendly messages
- Failed Firebase updates are logged to console
- UI remains responsive during Firebase operations
- Fallback to default states if Firebase unavailable

## Customization

### Device ID

Currently hardcoded as `'xiao_esp32s3'`. You can customize in:

- `_loadFeatureStatesFromFirebase()`
- `_updateFeatureInFirebase()`
- History screen navigation

### Room Management

Rooms are stored locally. For persistent room management, extend Firebase service to store available rooms per device.

### Feature Names

Update `FirebaseService._getFieldName()` if you want different field names in Firebase.
