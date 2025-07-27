#ifndef FIREBASE_HELPER_H
#define FIREBASE_HELPER_H

#include <Arduino.h>
#include <rpcWiFi.h>
#include <HTTPClient.h>

#define FIREBASE_DATABASE_URL "https://digisave-21992-default-rtdb.europe-west1.firebasedatabase.app"

unsigned long getTimestamp();
void sendTransactionToFirebase(String type, float amount, float newBalance);
void updateBalanceInFirebase(float balance);

#endif // FIREBASE_HELPER_H
