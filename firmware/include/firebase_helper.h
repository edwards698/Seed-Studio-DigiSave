#ifndef FIREBASE_HELPER_H
#define FIREBASE_HELPER_H

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>

// Function declarations
void logTransactionToFirestore(String type, double amount, double balanceAfter);
void logTransactionToFirestoreWithAPIKey(String type, double amount, double balanceAfter);
void sendTransactionToFirebase(String type, float amount, float newBalance);
void updateBalanceInFirebase(float balance);
unsigned long getTimestamp();
String getCurrentISOTimestamp();

#endif