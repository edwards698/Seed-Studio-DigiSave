#ifndef FIREBASE_HELPER_H
#define FIREBASE_HELPER_H

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>

// Function declarations
void sendTransactionToFirebase(String type, float amount, float newBalance);
void updateBalanceInFirebase(float balance);
unsigned long getTimestamp();

#endif