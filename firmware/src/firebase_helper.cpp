#include "firebase_helper.h"
#include "firestore_config.h"
#include <ArduinoJson.h>
#include <WiFiClientSecure.h>

void logTransactionToFirestore(String type, double amount, double balanceAfter)
{
    if (WiFi.status() != WL_CONNECTED)
    {
        Serial.println("[Firestore] WiFi not connected!");
        return;
    }

    // Use WiFiClientSecure for HTTPS
    WiFiClientSecure client;

    HTTPClient http;
    String url = "https://firestore.googleapis.com/v1/projects/";
    url += FIRESTORE_PROJECT_ID;
    url += "/databases/(default)/documents/transactions";

    // Prepare Firestore document JSON with proper structure
    StaticJsonDocument<1024> doc; // Increased size for safety

    JsonObject fields = doc.createNestedObject("fields");

    JsonObject typeField = fields.createNestedObject("type");
    typeField["stringValue"] = type;

    JsonObject amountField = fields.createNestedObject("amount");
    amountField["doubleValue"] = amount;

    JsonObject balanceField = fields.createNestedObject("balanceAfter");
    balanceField["doubleValue"] = balanceAfter;

    JsonObject timestampField = fields.createNestedObject("timestamp");
    timestampField["timestampValue"] = getCurrentISOTimestamp();

    JsonObject deviceField = fields.createNestedObject("device");
    deviceField["stringValue"] = "wio_terminal";

    String payload;
    serializeJson(doc, payload);

    Serial.println("[Firestore] Payload: " + payload);

    http.begin(client, url);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("Authorization", "Bearer " + String(FIRESTORE_API_KEY)); // Use Bearer token

    int httpCode = http.POST(payload);
    String response = http.getString();

    Serial.printf("[Firestore] POST transaction: %d\n", httpCode);
    if (httpCode < 0)
    {
        Serial.print("[Firestore] HTTP error: ");
        Serial.println(http.errorToString(httpCode));
    }
    Serial.print("[Firestore] Response: ");
    Serial.println(response);

    http.end();
}

// Alternative method using REST API with API key in URL
void logTransactionToFirestoreWithAPIKey(String type, double amount, double balanceAfter)
{
    if (WiFi.status() != WL_CONNECTED)
    {
        Serial.println("[Firestore] WiFi not connected!");
        return;
    }

    WiFiClientSecure client;

    HTTPClient http;
    String url = "https://firestore.googleapis.com/v1/projects/";
    url += FIRESTORE_PROJECT_ID;
    url += "/databases/(default)/documents/transactions?key=";
    url += FIRESTORE_API_KEY;

    // Prepare Firestore document JSON
    StaticJsonDocument<1024> doc;

    JsonObject fields = doc.createNestedObject("fields");

    JsonObject typeField = fields.createNestedObject("type");
    typeField["stringValue"] = type;

    JsonObject amountField = fields.createNestedObject("amount");
    amountField["doubleValue"] = amount;

    JsonObject balanceField = fields.createNestedObject("balanceAfter");
    balanceField["doubleValue"] = balanceAfter;

    JsonObject timestampField = fields.createNestedObject("timestamp");
    timestampField["timestampValue"] = getCurrentISOTimestamp();

    JsonObject deviceField = fields.createNestedObject("device");
    deviceField["stringValue"] = "wio_terminal";

    String payload;
    serializeJson(doc, payload);

    http.begin(client, url);
    http.addHeader("Content-Type", "application/json");

    int httpCode = http.POST(payload);
    String response = http.getString();

    Serial.printf("[Firestore] POST transaction (API Key): %d\n", httpCode);
    if (httpCode < 0)
    {
        Serial.print("[Firestore] HTTP error: ");
        Serial.println(http.errorToString(httpCode));
    }
    Serial.print("[Firestore] Response: ");
    Serial.println(response);

    http.end();
}

unsigned long getTimestamp()
{
    return millis() / 1000;
}

// Get current timestamp in ISO 8601 format for Firestore
String getCurrentISOTimestamp()
{
    // This is a simplified timestamp - in production you might want to use NTP
    unsigned long timestamp = getTimestamp();
    return "2024-01-01T00:00:" + String(timestamp % 60) + "Z";
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