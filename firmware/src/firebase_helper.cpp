#include "firebase_helper.h"

// Firebase configuration
#define FIREBASE_DATABASE_URL "https://digisave-21992-default-rtdb.europe-west1.firebasedatabase.app"

unsigned long getTimestamp()
{
    return millis() / 1000;
}

void sendTransactionToFirebase(String type, float amount, float newBalance)
{
    if (WiFi.status() != WL_CONNECTED)
    {
        Serial.println("[Firebase] WiFi not connected!");
        return;
    }

    HTTPClient http;
    String url = FIREBASE_DATABASE_URL;
    url += "/transactions.json";

    String payload = "{";
    payload += "\"type\":\"" + type + "\",";
    payload += "\"amount\":" + String(amount, 2) + ",";
    payload += "\"balanceAfter\":" + String(newBalance, 2) + ",";
    payload += "\"timestamp\":" + String(getTimestamp()) + ",";
    payload += "\"device\":\"wio_terminal\"";
    payload += "}";

    http.begin(url);
    http.addHeader("Content-Type", "application/json");

    int httpCode = http.POST(payload);
    String response = http.getString();

    http.end();

    Serial.printf("[Firebase] POST transaction: %d\n", httpCode);
    if (httpCode != 200)
    {
        Serial.println("[Firebase] Response: " + response);
    }
}

void updateBalanceInFirebase(float balance)
{
    if (WiFi.status() != WL_CONNECTED)
    {
        Serial.println("[Firebase] WiFi not connected!");
        return;
    }

    HTTPClient http;
    String url = FIREBASE_DATABASE_URL;
    url += "/account/balance.json";

    String payload = String(balance, 2);

    http.begin(url);
    http.addHeader("Content-Type", "application/json");

    int httpCode = http.PUT(payload);
    String response = http.getString();

    http.end();

    Serial.printf("[Firebase] PUT balance: %d\n", httpCode);
    if (httpCode != 200)
    {
        Serial.println("[Firebase] Response: " + response);
    }
}