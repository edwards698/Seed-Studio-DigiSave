#ifndef FIRESTORE_CONFIG_H
#define FIRESTORE_CONFIG_H

#if 0
// Firebase configuration for reference (from web):
// const firebaseConfig = {
//   apiKey: "AIzaSyDxb-BqKYJ2pNvU2crCoR3ERdYOqrLkn2U",
//   authDomain: "digisave-21992.firebaseapp.com",
//   databaseURL: "https://digisave-21992-default-rtdb.europe-west1.firebasedatabase.app",
//   projectId: "digisave-21992",
//   storageBucket: "digisave-21992.appspot.com",
//   messagingSenderId: "939533456242",
//   appId: "1:939533456242:web:11f4d0b69374ec9a1b03eb",
//   measurementId: "G-GBTQ3P7D44"
// };
#endif

#define FIREBASE_API_KEY "AIzaSyDxb-BqKYJ2pNvU2crCoR3ERdYOqrLkn2U"
#define FIREBASE_AUTH_DOMAIN "digisave-21992.firebaseapp.com"
#define FIREBASE_DATABASE_URL "https://digisave-21992-default-rtdb.europe-west1.firebasedatabase.app"
#define FIREBASE_PROJECT_ID "digisave-21992"
#define FIREBASE_STORAGE_BUCKET "digisave-21992.appspot.com"
#define FIREBASE_MESSAGING_SENDER_ID "939533456242"
#define FIREBASE_APP_ID "1:939533456242:web:11f4d0b69374ec9a1b03eb"
#define FIREBASE_MEASUREMENT_ID "G-GBTQ3P7D44"
#define FIRESTORE_PROJECT_ID FIREBASE_PROJECT_ID
#define FIRESTORE_API_KEY FIREBASE_API_KEY
#define FIRESTORE_REGION "us-central1" // or your Firestore region

#endif // FIRESTORE_CONFIG_H
