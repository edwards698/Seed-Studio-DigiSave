

#include <rpcWiFi.h>
#include <TFT_eSPI.h>
#include <HTTPClient.h>
#include "firebase_helper.h"

TFT_eSPI tft = TFT_eSPI();

enum Screen
{
  WIFI_SCAN,
  PASSWORD_INPUT,
  CONNECTING,
  TRACKPAD_BANKING,
  PIN_INPUT
};
Screen currentScreen = WIFI_SCAN;

String selectedSSID = "";
String inputPassword = "";
int selectedIndex = 0;
int totalNetworks = 0;

bool useUpperCase = false; // Toggle for Shift key
bool showPassword = false; // Toggle for password visibility
bool symbolsMode = false;  // Toggle for symbols/letters mode

// PIN authentication variables
String enteredPIN = "";
String correctPIN = "1111";           // Hardcoded PIN
bool showPINAsterisks = true;         // Always show asterisks for PIN
bool isAwaitingPIN = false;           // Flag to track if we're waiting for PIN
bool pinTransactionIsWithdraw = true; // Track transaction type for PIN entry

// QWERTY Keyboard layout (letters and numbers)
char baseKeys[4][10] = {
    {'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'},
    {'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'E'}, // 'E' for Eye (show/hide password)
    {'z', 'x', 'c', 'v', 'b', 'n', 'm', '0', '1', '2'},
    {'^', '3', '4', '5', '6', '7', '8', '9', '<', '@'} // '^' for Shift, '<' for backspace
};

// Symbols keyboard layout
char symbolKeys[4][10] = {
    {'!', '@', '#', '$', '%', '^', '&', '*', '(', ')'},
    {'-', '=', '[', ']', '\\', ';', '\'', ',', '.', '/'},
    {'~', '`', '{', '}', '|', ':', '"', '<', '>', '?'},
    {'S', '_', '+', '1', '2', '3', '4', '5', '6', '7'} // 'S' for Switch to letters
};

int cursorX = 0;
int cursorY = 0;
int lastCursorX = 0;
int lastCursorY = 0;
bool keyboardInitialized = false;

// Android-style colors
#define KEYBOARD_BG 0x1C1C     // Dark gray background
#define KEY_NORMAL 0x4A49      // Normal key color
#define KEY_PRESSED 0x5AEB     // Pressed key color (blue)
#define KEY_SPECIAL 0x39E7     // Special keys color
#define KEY_SYMBOLS 0x6B4D     // Symbols mode key color
#define TEXT_PRIMARY 0xFFFF    // White text
#define TEXT_SECONDARY 0xC618  // Light gray text
#define ACCENT_COLOR 0x5AEB    // Blue accent
#define INPUT_BG 0x2945        // Input field background
#define WITHDRAW_COLOR 0xF800  // Red for withdraw
#define DEPOSIT_COLOR 0x07E0   // Green for deposit
#define PIN_ERROR_COLOR 0xF800 // Red for PIN errors

// WiFi network display constants
#define NETWORK_HEIGHT 35      // Fixed height for each network item (increased from ~26)
#define NETWORK_TEXT_SIZE 2    // Fixed text size for network names
#define MAX_VISIBLE_NETWORKS 5 // Reduced to fit bigger items

// Trackpad variables
String trackpadAmount = "";
String accountBalance = "1250.75"; // Mock balance
int trackpadCursorX = 0;
int trackpadCursorY = 0;
int lastTrackpadCursorX = 0;
int lastTrackpadCursorY = 0;
bool trackpadInitialized = false;
bool isWithdrawMode = true; // true for withdraw, false for deposit

// Firebase configuration for reference (from web):
// const firebaseConfig = {
//   apiKey: "AIzaSyDxb-BqKYJ2pNvU2crCoR3ERdYOqrLkn2U",
//   authDomain: "digisave-21992.firebaseapp.com",
//   databaseURL: "https://digisave-21992-default-rtdb.europe-west1.firebasedatabase.app",
//   projectId: "digisave-21992",
//   storageBucket: "digisave-21992.firebasestorage.app",
//   messagingSenderId: "939533456242",
//   appId: "1:939533456242:web:11f4d0b69374ec9a1b03eb",
//   measurementId: "G-GBTQ3P7D44"
// };

// Firebase helper functions are now in firebase_helper.h/cpp

// Trackpad layout (4x4 grid including function keys)
char trackpadKeys[4][4] = {
    {'1', '2', '3', 'W'}, // W for Withdraw
    {'4', '5', '6', 'D'}, // D for Deposit
    {'7', '8', '9', 'C'}, // C for Clear
    {'.', '0', '#', 'E'}  // E for Execute/Enter
};

// ────────────── Forward Declarations ──────────────
void drawWiFiScreen();
void handleWiFiSelection();
void handleKeyboardInput();
void connectToWiFi();
void handleTrackpadInput();
void handlePINInput();
void createNewUserAccount();
void logTransactionToFirestore(String type, double amount, double balanceAfter);
void drawAllNetworks();
void drawSingleNetwork(int index);
void drawSignalBars(int x, int y, int rssi, uint16_t color);
void drawKeyboard();
void updateModeIndicator();
void drawConnectingScreen();
void drawTrackpadScreen();
void drawErrorScreen();
void updatePINDisplay();
void validatePIN();
void showPINError(String message);
void showPINSuccess();
void executeTransaction(float amount, bool isWithdraw);
void updateTransactionModeDisplay();
void drawTrackpad();
void drawSingleTrackpadKey(int x, int y, int keyW, int keyH, int keyRadius, int startX, int startY, int keySpacing);
void showTransactionMessage(String message, uint16_t color);

void setup()
{
  Serial.begin(115200);
  pinMode(WIO_5S_UP, INPUT);
  pinMode(WIO_5S_DOWN, INPUT);
  pinMode(WIO_5S_LEFT, INPUT);
  pinMode(WIO_5S_RIGHT, INPUT);
  pinMode(WIO_5S_PRESS, INPUT);
  pinMode(WIO_KEY_B, INPUT);
  pinMode(WIO_KEY_A, INPUT);
  pinMode(WIO_KEY_C, INPUT);

  tft.begin();
  tft.setRotation(3);
  tft.setTextSize(2);
  tft.setTextColor(TEXT_PRIMARY, TFT_BLACK);
  tft.fillScreen(TFT_BLACK);

  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(1000);

  totalNetworks = WiFi.scanNetworks();
  drawWiFiScreen();
}

void loop()
{
  switch (currentScreen)
  {
  case WIFI_SCAN:
    handleWiFiSelection();
    break;
  case PASSWORD_INPUT:
    handleKeyboardInput();
    break;
  case CONNECTING:
    connectToWiFi();
    break;
  case TRACKPAD_BANKING:
    handleTrackpadInput();
    break;
  case PIN_INPUT:
    handlePINInput();
    break;
  }
}

// ────────────── WiFi Scan Screen ──────────────
void drawWiFiScreen()
{
  tft.fillScreen(TFT_BLACK);

  // Title bar
  tft.fillRect(0, 0, 320, 35, ACCENT_COLOR);
  tft.setTextColor(TEXT_PRIMARY, ACCENT_COLOR);
  tft.setTextSize(2);
  tft.drawString("WiFi Networks", 10, 8);

  // Draw all networks initially
  drawAllNetworks();

  // Instructions - moved down to accommodate bigger network items
  tft.fillRect(0, 215, 320, 25, 0x2104);
  tft.setTextColor(TEXT_SECONDARY, 0x2104);
  tft.setTextSize(1);
  tft.drawString("Use UP/DOWN to navigate, CENTER to select", 10, 222);
}

void drawAllNetworks()
{
  for (int i = 0; i < totalNetworks && i < MAX_VISIBLE_NETWORKS; i++)
  {
    drawSingleNetwork(i);
  }
}

void drawSingleNetwork(int index)
{
  String ssid = WiFi.SSID(index);
  int rssi = WiFi.RSSI(index);
  int yPos = 45 + index * NETWORK_HEIGHT; // Fixed spacing

  // Truncate SSID if too long for consistent display
  String displaySSID = ssid;
  if (displaySSID.length() > 18)
  { // Limit characters for fixed size
    displaySSID = displaySSID.substring(0, 15) + "...";
  }

  // Clear the entire row first with fixed height
  tft.fillRect(5, yPos - 2, 310, NETWORK_HEIGHT - 1, TFT_BLACK);

  if (index == selectedIndex)
  {
    // Selected item background with fixed size
    tft.fillRoundRect(5, yPos - 2, 310, NETWORK_HEIGHT - 1, 6, ACCENT_COLOR);
    tft.setTextColor(TEXT_PRIMARY, ACCENT_COLOR);
    tft.setTextSize(NETWORK_TEXT_SIZE);        // Fixed text size
    tft.drawString(displaySSID, 15, yPos + 6); // Centered vertically in the fixed height

    // Signal strength indicator
    drawSignalBars(280, yPos + 8, rssi, TEXT_PRIMARY);
  }
  else
  {
    tft.setTextColor(TEXT_PRIMARY, TFT_BLACK);
    tft.setTextSize(NETWORK_TEXT_SIZE);        // Fixed text size
    tft.drawString(displaySSID, 15, yPos + 6); // Centered vertically in the fixed height

    // Signal strength indicator
    drawSignalBars(280, yPos + 8, rssi, TEXT_SECONDARY);
  }
}

void updateNetworkSelection(int oldIndex, int newIndex)
{
  // Only redraw the two affected items
  if (oldIndex >= 0 && oldIndex < totalNetworks && oldIndex < MAX_VISIBLE_NETWORKS)
  {
    drawSingleNetwork(oldIndex);
  }
  if (newIndex >= 0 && newIndex < totalNetworks && newIndex < MAX_VISIBLE_NETWORKS)
  {
    drawSingleNetwork(newIndex);
  }
}

void drawSignalBars(int x, int y, int rssi, uint16_t color)
{
  // Convert RSSI to signal strength (0-4 bars)
  int bars = 0;
  if (rssi > -50)
    bars = 4;
  else if (rssi > -60)
    bars = 3;
  else if (rssi > -70)
    bars = 2;
  else if (rssi > -80)
    bars = 1;

  // Slightly bigger signal bars
  for (int i = 0; i < 4; i++)
  {
    uint16_t barColor = (i < bars) ? color : 0x4208;
    int barHeight = 4 + i * 3;                                           // Increased from 3 + i * 2
    tft.fillRect(x + i * 5, y + 12 - barHeight, 3, barHeight, barColor); // Increased spacing and width
  }
}

void handleWiFiSelection()
{
  if (digitalRead(WIO_5S_UP) == LOW)
  {
    int oldIndex = selectedIndex;
    selectedIndex = (selectedIndex - 1 + totalNetworks) % totalNetworks;
    updateNetworkSelection(oldIndex, selectedIndex);
    delay(200);
  }
  if (digitalRead(WIO_5S_DOWN) == LOW)
  {
    int oldIndex = selectedIndex;
    selectedIndex = (selectedIndex + 1) % totalNetworks;
    updateNetworkSelection(oldIndex, selectedIndex);
    delay(200);
  }
  if (digitalRead(WIO_5S_PRESS) == LOW)
  {
    selectedSSID = WiFi.SSID(selectedIndex);
    inputPassword = "";
    cursorX = 0;
    cursorY = 0;
    lastCursorX = 0;
    lastCursorY = 0;
    keyboardInitialized = false;
    symbolsMode = false; // Start with letters
    currentScreen = PASSWORD_INPUT;
    drawKeyboard();
    delay(300);
  }
}

// ────────────── Password Input Screen ──────────────
char getCurrentKey()
{
  if (symbolsMode)
  {
    return symbolKeys[cursorY][cursorX];
  }
  else
  {
    return baseKeys[cursorY][cursorX];
  }
}

void drawSingleKey(int x, int y, int keyW, int keyH, int keyRadius, int startX, int startY, int keySpacing)
{
  int posX = startX + x * (keyW + keySpacing);
  int posY = startY + y * (keyH + keySpacing);

  char key;
  if (symbolsMode)
  {
    key = symbolKeys[y][x];
  }
  else
  {
    key = baseKeys[y][x];
  }

  // Apply case transformation for letters mode
  char displayKey = key;
  if (!symbolsMode && useUpperCase && key >= 'a' && key <= 'z')
  {
    displayKey = key - 32;
  }

  // Determine key colors and style
  uint16_t keyBg, keyBorder, textColor;
  bool isSelected = (x == cursorX && y == cursorY);
  bool isSpecialKey = false;

  if (!symbolsMode)
  {
    isSpecialKey = (key == '^' || key == '<' || key == 'E' || key == '@');
  }
  else
  {
    isSpecialKey = (key == 'S' || key == '_'); // 'S' for switch, '_' for space
  }

  if (isSelected)
  {
    keyBg = KEY_PRESSED;
    keyBorder = 0x7BEF;
    textColor = TEXT_PRIMARY;
  }
  else if (isSpecialKey)
  {
    keyBg = KEY_SPECIAL;
    keyBorder = 0x4A49;
    textColor = TEXT_PRIMARY;
  }
  else if (symbolsMode)
  {
    keyBg = KEY_SYMBOLS;
    keyBorder = 0x6B4D;
    textColor = TEXT_PRIMARY;
  }
  else
  {
    keyBg = KEY_NORMAL;
    keyBorder = 0x6B4D;
    textColor = TEXT_PRIMARY;
  }

  // Clear the area first to prevent artifacts
  tft.fillRect(posX - 1, posY - 1, keyW + 3, keyH + 4, KEYBOARD_BG);

  // Draw key with shadow effect
  if (!isSelected)
  {
    tft.fillRoundRect(posX + 1, posY + 2, keyW, keyH, keyRadius, 0x2104);
  }

  tft.fillRoundRect(posX, posY, keyW, keyH, keyRadius, keyBg);
  tft.drawRoundRect(posX, posY, keyW, keyH, keyRadius, keyBorder);

  // Add subtle gradient effect for selected key
  if (isSelected)
  {
    tft.drawRoundRect(posX + 1, posY + 1, keyW - 2, keyH - 2, keyRadius - 1, 0x9CF3);
  }

  // Draw key label (centered)
  tft.setTextColor(textColor, keyBg);
  tft.setTextSize(1);

  // Calculate text position for centering
  int textX = posX + keyW / 2;
  int textY = posY + keyH / 2 - 4;

  // Special key labels
  if (!symbolsMode)
  {
    if (key == '^')
    {
      tft.setTextColor(useUpperCase ? 0xFFE0 : textColor, keyBg);
      tft.drawString("SFT", textX - 9, textY);
    }
    else if (key == '<')
    {
      tft.drawString("DEL", textX - 9, textY);
    }
    else if (key == 'E')
    {
      // Eye key for show/hide password
      tft.setTextColor(showPassword ? 0xFFE0 : textColor, keyBg);
      tft.drawString("EYE", textX - 9, textY);
    }
    else if (key == '@')
    {
      tft.drawString("SYM", textX - 9, textY); // Change @ to SYM for symbols
    }
    else
    {
      tft.drawChar(displayKey, textX - 3, textY);
    }
  }
  else
  {
    if (key == 'S')
    {
      tft.drawString("ABC", textX - 9, textY);
    }
    else if (key == '_')
    {
      tft.drawString("SPC", textX - 9, textY);
    }
    else
    {
      tft.drawChar(key, textX - 3, textY);
    }
  }
}

void updateKeyboardCursor()
{
  // Keyboard key dimensions (must match drawKeyboard values)
  int keyW = 29;
  int keyH = 24;
  int keyRadius = 3;
  int totalKeyboardWidth = 10 * keyW + 9 * 2;
  int startX = (320 - totalKeyboardWidth) / 2;
  int startY = 85;
  int keySpacing = 2;

  // Redraw the previously selected key
  drawSingleKey(lastCursorX, lastCursorY, keyW, keyH, keyRadius, startX, startY, keySpacing);

  // Redraw the newly selected key
  drawSingleKey(cursorX, cursorY, keyW, keyH, keyRadius, startX, startY, keySpacing);

  // Update the last cursor position
  lastCursorX = cursorX;
  lastCursorY = cursorY;
}

void updatePasswordDisplay()
{
  // Clear the password input area
  tft.fillRoundRect(10, 50, 300, 25, 4, INPUT_BG);
  tft.drawRoundRect(10, 50, 300, 25, 4, ACCENT_COLOR);

  String displayPassword = showPassword ? inputPassword : String('*').substring(0, 0);
  if (!showPassword)
  {
    for (int i = 0; i < inputPassword.length(); i++)
    {
      displayPassword += "*";
    }
  }

  tft.setTextColor(TEXT_PRIMARY, INPUT_BG);
  tft.setTextSize(1);
  tft.drawString(displayPassword, 15, 57);
}

void updateCursor()
{
  // Calculate cursor position
  String displayPassword = showPassword ? inputPassword : String('*').substring(0, 0);
  if (!showPassword)
  {
    for (int i = 0; i < inputPassword.length(); i++)
    {
      displayPassword += "*";
    }
  }

  int cursorPos = 15 + displayPassword.length() * 6;

  // Blink cursor only - every 500ms
  if ((millis() / 500) % 2 == 0)
  {
    tft.fillRect(cursorPos, 57, 2, 12, TEXT_PRIMARY); // Show cursor
  }
  else
  {
    tft.fillRect(cursorPos, 57, 2, 12, INPUT_BG); // Hide cursor
  }
}

void updateAllKeys()
{
  // Update all keys when switching modes
  int keyW = 29;
  int keyH = 24;
  int keyRadius = 3;
  int totalKeyboardWidth = 10 * keyW + 9 * 2;
  int startX = (320 - totalKeyboardWidth) / 2;
  int startY = 85;
  int keySpacing = 2;

  // Redraw all keys
  for (int y = 0; y < 4; y++)
  {
    for (int x = 0; x < 10; x++)
    {
      drawSingleKey(x, y, keyW, keyH, keyRadius, startX, startY, keySpacing);
    }
  }

  // Update mode indicator
  updateModeIndicator();
}

void updateModeIndicator()
{
  // Clear and redraw the mode indicator
  tft.fillRect(250, 32, 70, 16, KEYBOARD_BG);
  tft.setTextColor(symbolsMode ? 0xFFE0 : TEXT_SECONDARY, KEYBOARD_BG);
  tft.setTextSize(1);
  String modeText = symbolsMode ? "[SYM]" : "[ABC]";
  if (!symbolsMode && useUpperCase)
  {
    modeText = "[ABC^]";
  }
  tft.drawString(modeText, 250, 32);
}

void drawKeyboard()
{
  tft.fillScreen(KEYBOARD_BG);

  // Title bar
  tft.fillRect(0, 0, 320, 30, ACCENT_COLOR);
  tft.setTextColor(TEXT_PRIMARY, ACCENT_COLOR);
  tft.setTextSize(1);
  tft.drawString("Enter Password", 10, 8);

  // Network name - bigger and centered
  tft.setTextColor(TEXT_PRIMARY, KEYBOARD_BG);
  tft.setTextSize(2);
  String truncatedSSID = selectedSSID;
  if (truncatedSSID.length() > 20)
  {
    truncatedSSID = truncatedSSID.substring(0, 17) + "...";
  }
  int textWidth = truncatedSSID.length() * 12;
  int centerX = (320 - textWidth) / 2;
  tft.drawString(truncatedSSID, centerX, 32);

  // Mode indicator
  updateModeIndicator();

  // Password input field - centered
  updatePasswordDisplay();

  // Keyboard keys - centered and bigger
  int keyW = 29;
  int keyH = 24;
  int keyRadius = 3;
  int totalKeyboardWidth = 10 * keyW + 9 * 2; // 10 keys + 9 spaces
  int startX = (320 - totalKeyboardWidth) / 2;
  int startY = 85;
  int keySpacing = 2;

  for (int y = 0; y < 4; y++)
  {
    for (int x = 0; x < 10; x++)
    {
      int posX = startX + x * (keyW + keySpacing);
      int posY = startY + y * (keyH + keySpacing);

      char key;
      if (symbolsMode)
      {
        key = symbolKeys[y][x];
      }
      else
      {
        key = baseKeys[y][x];
      }

      // Apply case transformation for letters mode
      char displayKey = key;
      if (!symbolsMode && useUpperCase && key >= 'a' && key <= 'z')
      {
        displayKey = key - 32;
      }

      // Determine key colors and style
      uint16_t keyBg, keyBorder, textColor;
      bool isSelected = (x == cursorX && y == cursorY);
      bool isSpecialKey = false;

      if (!symbolsMode)
      {
        isSpecialKey = (key == '^' || key == '<' || key == 'E' || key == '@');
      }
      else
      {
        isSpecialKey = (key == 'S' || key == '_');
      }

      if (isSelected)
      {
        keyBg = KEY_PRESSED;
        keyBorder = 0x7BEF;
        textColor = TEXT_PRIMARY;
      }
      else if (isSpecialKey)
      {
        keyBg = KEY_SPECIAL;
        keyBorder = 0x4A49;
        textColor = TEXT_PRIMARY;
      }
      else if (symbolsMode)
      {
        keyBg = KEY_SYMBOLS;
        keyBorder = 0x6B4D;
        textColor = TEXT_PRIMARY;
      }
      else
      {
        keyBg = KEY_NORMAL;
        keyBorder = 0x6B4D;
        textColor = TEXT_PRIMARY;
      }

      // Draw key with shadow effect
      if (!isSelected)
      {
        tft.fillRoundRect(posX + 1, posY + 2, keyW, keyH, keyRadius, 0x2104);
      }

      tft.fillRoundRect(posX, posY, keyW, keyH, keyRadius, keyBg);
      tft.drawRoundRect(posX, posY, keyW, keyH, keyRadius, keyBorder);

      // Add subtle gradient effect for selected key
      if (isSelected)
      {
        tft.drawRoundRect(posX + 1, posY + 1, keyW - 2, keyH - 2, keyRadius - 1, 0x9CF3);
      }

      // Draw key label (centered)
      tft.setTextColor(textColor, keyBg);
      tft.setTextSize(1);

      // Calculate text position for centering
      int textX = posX + keyW / 2;
      int textY = posY + keyH / 2 - 4;

      // Special key labels
      if (!symbolsMode)
      {
        if (key == '^')
        {
          tft.setTextColor(useUpperCase ? 0xFFE0 : textColor, keyBg);
          tft.drawString("SFT", textX - 9, textY);
        }
        else if (key == '<')
        {
          tft.drawString("DEL", textX - 9, textY);
        }
        else if (key == 'E')
        {
          // Eye key for show/hide password
          tft.setTextColor(showPassword ? 0xFFE0 : textColor, keyBg);
          tft.drawString("EYE", textX - 9, textY);
        }
        else if (key == '@')
        {
          tft.drawString("SYM", textX - 9, textY);
        }
        else
        {
          tft.drawChar(displayKey, textX - 3, textY);
        }
      }
      else
      {
        if (key == 'S')
        {
          tft.drawString("ABC", textX - 9, textY);
        }
        else if (key == '_')
        {
          tft.drawString("SPC", textX - 9, textY);
        }
        else
        {
          tft.drawChar(key, textX - 3, textY);
        }
      }
    }
  }

  // Bottom action bar - moved down and made bigger
  tft.fillRect(0, 210, 320, 30, 0x2945);
  tft.setTextColor(TEXT_SECONDARY, 0x2945);
  tft.setTextSize(1);
  tft.drawString("B:Back to WiFi", 15, 218);
  tft.drawString("C:Connect", 120, 218);
  tft.drawString("A:Backspace", 200, 218);

  keyboardInitialized = true;
}

void handleKeyboardInput()
{
  // Update cursor blinking only (not the whole password display)
  static unsigned long lastCursorUpdate = 0;
  if (millis() - lastCursorUpdate > 50)
  { // Update every 50ms for smooth cursor blinking
    updateCursor();
    lastCursorUpdate = millis();
  }

  if (digitalRead(WIO_5S_UP) == LOW)
  {
    cursorY = (cursorY - 1 + 4) % 4;
    if (keyboardInitialized)
    {
      updateKeyboardCursor();
    }
    else
    {
      drawKeyboard();
    }
    delay(150);
  }
  if (digitalRead(WIO_5S_DOWN) == LOW)
  {
    cursorY = (cursorY + 1) % 4;
    if (keyboardInitialized)
    {
      updateKeyboardCursor();
    }
    else
    {
      drawKeyboard();
    }
    delay(150);
  }
  if (digitalRead(WIO_5S_LEFT) == LOW)
  {
    cursorX = (cursorX - 1 + 10) % 10;
    if (keyboardInitialized)
    {
      updateKeyboardCursor();
    }
    else
    {
      drawKeyboard();
    }
    delay(150);
  }
  if (digitalRead(WIO_5S_RIGHT) == LOW)
  {
    cursorX = (cursorX + 1) % 10;
    if (keyboardInitialized)
    {
      updateKeyboardCursor();
    }
    else
    {
      drawKeyboard();
    }
    delay(150);
  }

  if (digitalRead(WIO_5S_PRESS) == LOW)
  {
    char key = getCurrentKey();

    if (!symbolsMode)
    {
      // Letters/numbers mode
      if (key == '<')
      {
        // Backspace
        if (inputPassword.length() > 0)
        {
          inputPassword.remove(inputPassword.length() - 1);
          updatePasswordDisplay();
        }
      }
      else if (key == 'E')
      {
        // Eye key - toggle password visibility
        showPassword = !showPassword;
        updatePasswordDisplay();
        updateKeyboardCursor(); // Update the EYE key appearance
      }
      else if (key == '^')
      {
        // Shift toggle
        useUpperCase = !useUpperCase;
        updateAllKeys();
      }
      else if (key == '@')
      {
        // Switch to symbols mode
        symbolsMode = true;
        updateAllKeys();
      }
      else
      {
        // Regular character
        if (useUpperCase && key >= 'a' && key <= 'z')
        {
          key -= 32;
        }
        inputPassword += key;
        updatePasswordDisplay();
      }
    }
    else
    {
      // Symbols mode
      if (key == 'S')
      {
        // Switch back to letters mode
        symbolsMode = false;
        updateAllKeys();
      }
      else if (key == '_')
      {
        // Space
        inputPassword += ' ';
        updatePasswordDisplay();
      }
      else
      {
        // Symbol character
        inputPassword += key;
        updatePasswordDisplay();
      }
    }
    delay(200);
  }

  if (digitalRead(WIO_KEY_A) == LOW)
  {
    // Backspace function moved to A button
    if (inputPassword.length() > 0)
    {
      inputPassword.remove(inputPassword.length() - 1);
      updatePasswordDisplay();
    }
    delay(200);
  }

  if (digitalRead(WIO_KEY_B) == LOW)
  {
    // Go back to WiFi selection screen
    currentScreen = WIFI_SCAN;
    drawWiFiScreen();
    delay(300);
  }

  if (digitalRead(WIO_KEY_C) == LOW)
  {
    if (inputPassword.length() > 0)
    {
      currentScreen = CONNECTING;
      drawConnectingScreen();
    }
    delay(300);
  }
}

// ────────────── Connecting Screen ──────────────
void drawConnectingScreen()
{
  tft.fillScreen(TFT_BLACK);

  // Title
  tft.setTextColor(ACCENT_COLOR, TFT_BLACK);
  tft.setTextSize(3);
  tft.drawString("Connecting", 70, 40);

  // Network info
  tft.setTextColor(TEXT_PRIMARY, TFT_BLACK);
  tft.setTextSize(2);
  tft.drawString("Network:", 10, 100);
  tft.drawString(selectedSSID, 10, 125);
}

void connectToWiFi()
{
  WiFi.begin(selectedSSID.c_str(), inputPassword.c_str());

  int tries = 0;
  int dotCount = 0;

  while (WiFi.status() != WL_CONNECTED && tries < 20)
  {
    // Animated dots
    tft.fillRect(10, 160, 300, 30, TFT_BLACK);
    tft.setTextColor(ACCENT_COLOR, TFT_BLACK);
    tft.setTextSize(2);

    String dots = "";
    for (int i = 0; i < (dotCount % 4); i++)
    {
      dots += ".";
    }
    tft.drawString("Connecting" + dots, 10, 160);

    delay(500);
    tries++;
    dotCount++;
  }

  if (WiFi.status() == WL_CONNECTED)
  {

    // Go directly to banking terminal after successful WiFi connection
    trackpadAmount = "";
    trackpadCursorX = 0;
    trackpadCursorY = 0;
    lastTrackpadCursorX = 0;
    lastTrackpadCursorY = 0;
    trackpadInitialized = false;
    isWithdrawMode = true; // Default to withdraw
    currentScreen = TRACKPAD_BANKING;
    drawTrackpadScreen();
  }
  else
  {
    drawErrorScreen();
  }
}

void drawErrorScreen()
{
  tft.fillScreen(0xF800); // Red background
  tft.setTextColor(TEXT_PRIMARY, 0xF800);
  tft.setTextSize(2);
  tft.drawString("Connection Failed!", 50, 80);
  tft.setTextSize(1);
  tft.drawString("Check password and try again", 60, 120);
  tft.drawString("Press any key to go back", 70, 140);

  // Wait for any button press
  while (true)
  {
    if (digitalRead(WIO_5S_PRESS) == LOW || digitalRead(WIO_KEY_A) == LOW || digitalRead(WIO_KEY_B) == LOW || digitalRead(WIO_KEY_C) == LOW)
    {
      keyboardInitialized = false;
      currentScreen = PASSWORD_INPUT;
      drawKeyboard();
      delay(500);
      break;
    }
  }
}

// ────────────── PIN Input Screen ──────────────
void drawPINScreen()
{
  tft.fillScreen(KEYBOARD_BG);

  // Title bar
  tft.fillRect(0, 0, 320, 30, ACCENT_COLOR);
  tft.setTextColor(TEXT_PRIMARY, ACCENT_COLOR);
  tft.setTextSize(1);
  String transactionType = pinTransactionIsWithdraw ? "Withdraw" : "Deposit";
  tft.drawString("Enter PIN for " + transactionType, 10, 8);

  // Security message
  tft.setTextColor(TEXT_PRIMARY, KEYBOARD_BG);
  tft.setTextSize(1);
  tft.drawString("Enter your 4-digit PIN", 100, 32);

  // PIN input field - centered
  updatePINDisplay();

  // PIN Numeric keypad - 3x4 grid plus special keys
  int keyW = 50;
  int keyH = 35;
  int keyRadius = 5;
  int totalKeyboardWidth = 3 * keyW + 2 * 8; // 3 keys + 2 spaces
  int startX = (320 - totalKeyboardWidth) / 2;
  int startY = 85;
  int keySpacing = 8;

  // PIN keypad layout (3x4 plus special keys)
  char pinKeys[5][3] = {
      {'1', '2', '3'},
      {'4', '5', '6'},
      {'7', '8', '9'},
      {'C', '0', '<'}, // C=Clear, <=Backspace
      {'B', 'E', 'S'}  // B=Back, E=Enter, S=Show/Hide (not used for PIN)
  };

  for (int y = 0; y < 5; y++)
  {
    for (int x = 0; x < 3; x++)
    {
      int posX = startX + x * (keyW + keySpacing);
      int posY = startY + y * (keyH + keySpacing);

      char key = pinKeys[y][x];

      // Determine key colors and style
      uint16_t keyBg, keyBorder, textColor;
      bool isSelected = (x == cursorX && y == cursorY);
      bool isSpecialKey = (key == 'C' || key == '<' || key == 'B' || key == 'E' || key == 'S');

      if (isSelected)
      {
        keyBg = KEY_PRESSED;
        keyBorder = 0x7BEF;
        textColor = TEXT_PRIMARY;
      }
      else if (isSpecialKey)
      {
        keyBg = KEY_SPECIAL;
        keyBorder = 0x4A49;
        textColor = TEXT_PRIMARY;
      }
      else
      {
        keyBg = KEY_NORMAL;
        keyBorder = 0x6B4D;
        textColor = TEXT_PRIMARY;
      }

      // Draw key with shadow effect
      if (!isSelected)
      {
        tft.fillRoundRect(posX + 2, posY + 3, keyW, keyH, keyRadius, 0x2104);
      }

      tft.fillRoundRect(posX, posY, keyW, keyH, keyRadius, keyBg);
      tft.drawRoundRect(posX, posY, keyW, keyH, keyRadius, keyBorder);

      // Add subtle gradient effect for selected key
      if (isSelected)
      {
        tft.drawRoundRect(posX + 1, posY + 1, keyW - 2, keyH - 2, keyRadius - 1, 0x9CF3);
      }

      // Draw key label (centered)
      tft.setTextColor(textColor, keyBg);
      tft.setTextSize(2);

      // Calculate text position for centering
      int textX = posX + keyW / 2;
      int textY = posY + keyH / 2 - 8;

      // Special key labels
      if (key == 'C')
      {
        tft.setTextSize(1);
        tft.drawString("CLR", textX - 12, textY + 4);
      }
      else if (key == '<')
      {
        tft.setTextSize(1);
        tft.drawString("DEL", textX - 12, textY + 4);
      }
      else if (key == 'B')
      {
        tft.setTextSize(1);
        tft.drawString("BACK", textX - 15, textY + 4);
      }
      else if (key == 'E')
      {
        tft.setTextSize(1);
        tft.drawString("ENTER", textX - 18, textY + 4);
      }
      else if (key == 'S')
      {
        // This key is not used in PIN mode, make it inactive
        keyBg = 0x2104;
        tft.fillRoundRect(posX, posY, keyW, keyH, keyRadius, keyBg);
        tft.setTextSize(1);
        tft.setTextColor(0x4208, keyBg);
        tft.drawString("---", textX - 12, textY + 4);
      }
      else
      {
        tft.drawChar(key, textX - 8, textY);
      }
    }
  }

  // Bottom action bar
  tft.fillRect(0, 210, 320, 30, 0x2945);
  tft.setTextColor(TEXT_SECONDARY, 0x2945);
  tft.setTextSize(1);
  tft.drawString("Navigate with D-pad", 15, 218);
  tft.drawString("CENTER to select", 150, 218);
  tft.drawString("A:Clear", 250, 218);

  keyboardInitialized = true;
}

void updatePINDisplay()
{
  // Clear the PIN input area
  tft.fillRoundRect(10, 50, 300, 25, 4, INPUT_BG);
  tft.drawRoundRect(10, 50, 300, 25, 4, ACCENT_COLOR);

  // Always show asterisks for PIN
  String displayPIN = "";
  for (int i = 0; i < enteredPIN.length(); i++)
  {
    displayPIN += "*";
  }

  tft.setTextColor(TEXT_PRIMARY, INPUT_BG);
  tft.setTextSize(2);

  // Center the PIN display
  int textWidth = displayPIN.length() * 12;
  int centerX = 160 - textWidth / 2;
  tft.drawString(displayPIN, centerX, 55);
}

void updatePINCursor()
{
  // Only update cursor blinking
  int textWidth = enteredPIN.length() * 12;
  int centerX = 160 - textWidth / 2;
  int cursorPos = centerX + textWidth;

  // Blink cursor
  if ((millis() / 500) % 2 == 0)
  {
    tft.fillRect(cursorPos, 55, 2, 15, TEXT_PRIMARY); // Show cursor
  }
  else
  {
    tft.fillRect(cursorPos, 55, 2, 15, INPUT_BG); // Hide cursor
  }
}

void handlePINInput()
{
  // Update cursor blinking
  static unsigned long lastCursorUpdate = 0;
  if (millis() - lastCursorUpdate > 50)
  {
    updatePINCursor();
    lastCursorUpdate = millis();
  }

  // PIN keypad layout (3x4 plus special keys)
  char pinKeys[5][3] = {
      {'1', '2', '3'},
      {'4', '5', '6'},
      {'7', '8', '9'},
      {'C', '0', '<'}, // C=Clear, <=Backspace
      {'B', 'E', 'S'}  // B=Back, E=Enter, S=Show/Hide (not used for PIN)
  };

  if (digitalRead(WIO_5S_UP) == LOW)
  {
    cursorY = (cursorY - 1 + 5) % 5;
    if (keyboardInitialized)
    {
      drawPINScreen(); // Redraw entire screen for simplicity
    }
    delay(150);
  }
  if (digitalRead(WIO_5S_DOWN) == LOW)
  {
    cursorY = (cursorY + 1) % 5;
    if (keyboardInitialized)
    {
      drawPINScreen(); // Redraw entire screen for simplicity
    }
    delay(150);
  }
  if (digitalRead(WIO_5S_LEFT) == LOW)
  {
    cursorX = (cursorX - 1 + 3) % 3;
    if (keyboardInitialized)
    {
      drawPINScreen(); // Redraw entire screen for simplicity
    }
    delay(150);
  }
  if (digitalRead(WIO_5S_RIGHT) == LOW)
  {
    cursorX = (cursorX + 1) % 3;
    if (keyboardInitialized)
    {
      drawPINScreen(); // Redraw entire screen for simplicity
    }
    delay(150);
  }

  if (digitalRead(WIO_5S_PRESS) == LOW)
  {
    char key = pinKeys[cursorY][cursorX];

    if (key >= '0' && key <= '9')
    {
      // Add digit to PIN (max 4 digits)
      if (enteredPIN.length() < 4)
      {
        enteredPIN += key;
        updatePINDisplay();
      }
    }
    else if (key == '<')
    {
      // Backspace
      if (enteredPIN.length() > 0)
      {
        enteredPIN.remove(enteredPIN.length() - 1);
        updatePINDisplay();
      }
    }
    else if (key == 'C')
    {
      // Clear all
      enteredPIN = "";
      updatePINDisplay();
    }
    else if (key == 'E')
    {
      // Enter - validate PIN
      if (enteredPIN.length() == 4)
      {
        validatePIN();
      }
      else
      {
        showPINError("PIN must be 4 digits!");
      }
    }
    else if (key == 'B')
    {
      // Back to banking screen
      enteredPIN = "";
      isAwaitingPIN = false;
      currentScreen = TRACKPAD_BANKING;
      drawTrackpadScreen();
    }
    delay(200);
  }

  if (digitalRead(WIO_KEY_A) == LOW)
  {
    // Clear PIN
    enteredPIN = "";
    updatePINDisplay();
    delay(200);
  }

  if (digitalRead(WIO_KEY_B) == LOW)
  {
    // Back to banking screen
    enteredPIN = "";
    isAwaitingPIN = false;
    currentScreen = TRACKPAD_BANKING;
    drawTrackpadScreen();
    delay(300);
  }

  if (digitalRead(WIO_KEY_C) == LOW)
  {
    // Enter PIN
    if (enteredPIN.length() == 4)
    {
      validatePIN();
    }
    else
    {
      showPINError("PIN must be 4 digits!");
    }
    delay(300);
  }
}

void validatePIN()
{
  if (enteredPIN == correctPIN)
  {
    // PIN correct - proceed with transaction
    showPINSuccess();
    // Process the pending transaction
    float amount = trackpadAmount.toFloat();
    if (amount > 0)
    {
      executeTransaction(amount, pinTransactionIsWithdraw);
    }

    // Return to banking screen
    enteredPIN = "";
    isAwaitingPIN = false;
    currentScreen = TRACKPAD_BANKING;
    drawTrackpadScreen();
  }
  else
  {
    // PIN incorrect
    showPINError("Incorrect PIN! Try again.");
    enteredPIN = "";
    updatePINDisplay();
  }
}

void showPINError(String message)
{
  // Show error message temporarily
  tft.fillRect(10, 75, 300, 15, TFT_BLACK);
  tft.setTextColor(PIN_ERROR_COLOR, TFT_BLACK);
  tft.setTextSize(1);
  int textWidth = message.length() * 6;
  int centerX = 160 - textWidth / 2;
  tft.drawString(message, centerX, 77);
  delay(2000);
  tft.fillRect(10, 75, 300, 15, TFT_BLACK); // Clear error message
}

void showPINSuccess()
{
  // Show success message temporarily
  tft.fillRect(10, 75, 300, 15, TFT_BLACK);
  tft.setTextColor(DEPOSIT_COLOR, TFT_BLACK);
  tft.setTextSize(1);
  String message = "PIN Correct!";
  int textWidth = message.length() * 6;
  int centerX = 160 - textWidth / 2;
  tft.drawString(message, centerX, 77);
  delay(1500);
}

void executeTransaction(float amount, bool isWithdraw)
{
  float balance = accountBalance.toFloat();

  if (isWithdraw)
  {
    if (amount > balance)
    {
      showTransactionMessage("Insufficient funds!", WITHDRAW_COLOR);
      return;
    }
    balance -= amount;
    accountBalance = String(balance, 2);
    sendTransactionToFirebase("withdraw", amount, balance);
    showTransactionMessage("Withdrawal successful!", DEPOSIT_COLOR);
  }
  else
  {
    balance += amount;
    accountBalance = String(balance, 2);
    sendTransactionToFirebase("deposit", amount, balance);
    showTransactionMessage("Deposit successful!", DEPOSIT_COLOR);
  }
  updateBalanceInFirebase(balance);
  trackpadAmount = "";
  delay(2000);
}

// ────────────── Trackpad Banking Screen ──────────────
void drawTrackpadScreen()
{
  tft.fillScreen(TFT_BLACK);

  // Title bar - more compact
  tft.fillRect(0, 0, 320, 25, ACCENT_COLOR);
  tft.setTextColor(TEXT_PRIMARY, ACCENT_COLOR);
  tft.setTextSize(1);
  tft.drawString("Banking Terminal", 10, 6);

  // Connection status - show WiFi connection info
  tft.setTextColor(0x07E0, TFT_BLACK); // Green color
  tft.setTextSize(1);
  tft.drawString("Connected: " + selectedSSID, 170, 6);

  // Account balance display - smaller and positioned higher
  tft.fillRoundRect(10, 30, 150, 18, 3, 0x2945);
  tft.setTextColor(0x07E0, 0x2945); // Green for balance
  tft.setTextSize(1);
  tft.drawString("Bal: $" + accountBalance, 15, 36);

  // Transaction mode indicator - positioned to the right, smaller
  updateTransactionModeDisplay();

  // Amount input display area - smaller and positioned higher
  tft.fillRoundRect(10, 53, 300, 22, 3, INPUT_BG);
  tft.drawRoundRect(10, 53, 300, 22, 3, ACCENT_COLOR);

  // Transaction status area - more compact
  tft.fillRect(10, 80, 300, 12, TFT_BLACK);
  tft.setTextColor(TEXT_SECONDARY, TFT_BLACK);
  tft.setTextSize(1);
  tft.drawString("W=Withdraw D=Deposit C=Clear E=Execute", 10, 82);

  // Trackpad area - positioned to show all buttons clearly
  drawTrackpad();

  // Additional info below trackpad
  tft.fillRect(10, 205, 300, 12, TFT_BLACK);
  tft.setTextColor(TEXT_SECONDARY, TFT_BLACK);
  tft.setTextSize(1);
  tft.drawString("PIN required for transactions", 10, 207);

  // Instructions - bottom bar
  tft.fillRect(0, 220, 320, 20, 0x2945);
  tft.setTextColor(TEXT_SECONDARY, 0x2945);
  tft.setTextSize(1);
  tft.drawString("A:Clear B:WiFi C:Process", 10, 226);

  trackpadInitialized = true;
}

void updateTransactionModeDisplay()
{
  // Clear the mode display area - positioned on the right side, smaller
  tft.fillRect(170, 30, 70, 18, TFT_BLACK);

  // Display current mode with appropriate color
  if (isWithdrawMode)
  {
    tft.fillRoundRect(170, 30, 70, 18, 3, WITHDRAW_COLOR);
    tft.setTextColor(TEXT_PRIMARY, WITHDRAW_COLOR);
    tft.setTextSize(1);
    tft.drawString("WITHDRAW", 175, 36);
  }
  else
  {
    tft.fillRoundRect(170, 30, 70, 18, 3, DEPOSIT_COLOR);
    tft.setTextColor(TEXT_PRIMARY, DEPOSIT_COLOR);
    tft.setTextSize(1);
    tft.drawString("DEPOSIT", 180, 36);
  }
}

void drawTrackpad()
{
  int keyW = 25; // Even smaller width
  int keyH = 20; // Even smaller height
  int keyRadius = 2;
  int startX = (320 - (4 * keyW + 3 * 3)) / 2; // Center the 4-column trackpad with minimal spacing
  int startY = 110;                            // Moved up more
  int keySpacing = 3;                          // Minimal spacing

  for (int y = 0; y < 4; y++)
  {
    for (int x = 0; x < 4; x++)
    {
      drawSingleTrackpadKey(x, y, keyW, keyH, keyRadius, startX, startY, keySpacing);
    }
  }
}

void drawSingleTrackpadKey(int x, int y, int keyW, int keyH, int keyRadius, int startX, int startY, int keySpacing)
{
  int posX = startX + x * (keyW + keySpacing);
  int posY = startY + y * (keyH + keySpacing);

  char key = trackpadKeys[y][x];
  bool isSelected = (x == trackpadCursorX && y == trackpadCursorY);

  // Determine key colors based on function
  uint16_t keyBg, keyBorder, textColor;
  bool isSpecialKey = false;

  if (key == 'W' || key == 'D' || key == 'C' || key == 'E')
  {
    isSpecialKey = true;
  }

  if (isSelected)
  {
    keyBg = KEY_PRESSED;
    keyBorder = 0x7BEF;
    textColor = TEXT_PRIMARY;
  }
  else if (isSpecialKey)
  {
    if (key == 'W')
    {
      keyBg = WITHDRAW_COLOR;
      keyBorder = 0xC000;
    }
    else if (key == 'D')
    {
      keyBg = DEPOSIT_COLOR;
      keyBorder = 0x05C0;
    }
    else
    {
      keyBg = KEY_SPECIAL;
      keyBorder = 0x4A49;
    }
    textColor = TEXT_PRIMARY;
  }
  else
  {
    keyBg = KEY_NORMAL;
    keyBorder = 0x6B4D;
    textColor = TEXT_PRIMARY;
  }

  // Clear the area first
  tft.fillRect(posX - 1, posY - 1, keyW + 2, keyH + 2, TFT_BLACK);

  // Draw key - no shadow for very small keys
  tft.fillRoundRect(posX, posY, keyW, keyH, keyRadius, keyBg);
  tft.drawRoundRect(posX, posY, keyW, keyH, keyRadius, keyBorder);

  // Add simple highlight for selected key
  if (isSelected)
  {
    tft.drawRoundRect(posX + 1, posY + 1, keyW - 2, keyH - 2, keyRadius - 1, 0x9CF3);
  }

  // Draw key label - very small text for tiny keys
  tft.setTextColor(textColor, keyBg);
  tft.setTextSize(1);

  // Calculate text position for centering
  int textX = posX + keyW / 2 - 3;
  int textY = posY + keyH / 2 - 4;

  // All keys use single character labels for tiny size
  tft.drawChar(key, textX, textY);
}

void updateTrackpadAmountDisplay()
{
  // Clear and redraw the amount input area
  tft.fillRoundRect(10, 53, 300, 22, 3, INPUT_BG);
  tft.drawRoundRect(10, 53, 300, 22, 3, ACCENT_COLOR);

  // Display dollar sign and amount
  String displayAmount = "$" + trackpadAmount;
  if (trackpadAmount.length() == 0)
  {
    displayAmount = "$0.00";
  }

  tft.setTextColor(TEXT_PRIMARY, INPUT_BG);
  tft.setTextSize(1);
  tft.drawString(displayAmount, 15, 60);

  // Draw cursor - smaller
  int cursorPos = 15 + displayAmount.length() * 6;
  if ((millis() / 500) % 2 == 0)
  {
    tft.fillRect(cursorPos, 60, 1, 10, TEXT_PRIMARY);
  }
  else
  {
    tft.fillRect(cursorPos, 60, 1, 10, INPUT_BG);
  }
}

void updateTrackpadCursor()
{
  // Trackpad key dimensions - updated to match smaller size
  int keyW = 25;
  int keyH = 20;
  int keyRadius = 2;
  int startX = (320 - (4 * keyW + 3 * 3)) / 2;
  int startY = 110;
  int keySpacing = 3;

  // Redraw the previously selected key
  drawSingleTrackpadKey(lastTrackpadCursorX, lastTrackpadCursorY, keyW, keyH, keyRadius, startX, startY, keySpacing);

  // Redraw the newly selected key
  drawSingleTrackpadKey(trackpadCursorX, trackpadCursorY, keyW, keyH, keyRadius, startX, startY, keySpacing);

  // Update the last cursor position
  lastTrackpadCursorX = trackpadCursorX;
  lastTrackpadCursorY = trackpadCursorY;
}

void processTransaction()
{
  float amount = trackpadAmount.toFloat();
  float balance = accountBalance.toFloat();

  if (amount <= 0)
  {
    showTransactionMessage("Invalid amount!", 0xF800);
    return;
  }

  if (isWithdrawMode && amount > balance)
  {
    showTransactionMessage("Insufficient funds!", 0xF800);
    return;
  }

  // Show PIN entry screen
  enteredPIN = "";
  pinTransactionIsWithdraw = isWithdrawMode;
  isAwaitingPIN = true;
  cursorX = 1; // Start at middle position
  cursorY = 0;
  lastCursorX = 1;
  lastCursorY = 0;
  keyboardInitialized = false;
  currentScreen = PIN_INPUT;
  drawPINScreen();
}

void showTransactionMessage(String message, uint16_t color)
{
  tft.fillRect(10, 80, 300, 12, TFT_BLACK);
  tft.setTextColor(color, TFT_BLACK);
  tft.setTextSize(1);
  tft.drawString(message, 10, 82);
  delay(2000);
  tft.fillRect(10, 80, 300, 12, TFT_BLACK); // Clear message
  // Restore instruction text
  tft.setTextColor(TEXT_SECONDARY, TFT_BLACK);
  tft.drawString("W=Withdraw D=Deposit C=Clear E=Execute", 10, 82);
}

void handleTrackpadInput()
{
  // Update display regularly for cursor blinking
  static unsigned long lastDisplayUpdate = 0;
  if (millis() - lastDisplayUpdate > 50)
  {
    updateTrackpadAmountDisplay();
    lastDisplayUpdate = millis();
  }

  // Handle navigation
  if (digitalRead(WIO_5S_UP) == LOW)
  {
    trackpadCursorY = (trackpadCursorY - 1 + 4) % 4;
    if (trackpadInitialized)
    {
      updateTrackpadCursor();
    }
    delay(150);
  }
  if (digitalRead(WIO_5S_DOWN) == LOW)
  {
    trackpadCursorY = (trackpadCursorY + 1) % 4;
    if (trackpadInitialized)
    {
      updateTrackpadCursor();
    }
    delay(150);
  }
  if (digitalRead(WIO_5S_LEFT) == LOW)
  {
    trackpadCursorX = (trackpadCursorX - 1 + 4) % 4;
    if (trackpadInitialized)
    {
      updateTrackpadCursor();
    }
    delay(150);
  }
  if (digitalRead(WIO_5S_RIGHT) == LOW)
  {
    trackpadCursorX = (trackpadCursorX + 1) % 4;
    if (trackpadInitialized)
    {
      updateTrackpadCursor();
    }
    delay(150);
  }

  // Handle key press
  if (digitalRead(WIO_5S_PRESS) == LOW)
  {
    char key = trackpadKeys[trackpadCursorY][trackpadCursorX];

    if (key == 'W')
    {
      // Switch to withdraw mode
      isWithdrawMode = true;
      updateTransactionModeDisplay();
    }
    else if (key == 'D')
    {
      // Switch to deposit mode
      isWithdrawMode = false;
      updateTransactionModeDisplay();
    }
    else if (key == 'C')
    {
      // Clear amount
      trackpadAmount = "";
      updateTrackpadAmountDisplay();
    }
    else if (key == 'E')
    {
      // Execute transaction (now requires PIN)
      processTransaction();
    }
    else if (key >= '0' && key <= '9' || key == '.')
    {
      // Add digit or decimal point
      if (key == '.' && trackpadAmount.indexOf('.') >= 0)
      {
        // Don't add multiple decimal points
      }
      else
      {
        trackpadAmount += key;
        updateTrackpadAmountDisplay();
      }
    }
    else if (key == '#')
    {
      // Use # as backspace for trackpad
      if (trackpadAmount.length() > 0)
      {
        trackpadAmount.remove(trackpadAmount.length() - 1);
        updateTrackpadAmountDisplay();
      }
    }
    delay(200);
  }

  // Handle function buttons
  if (digitalRead(WIO_KEY_A) == LOW)
  {
    // Clear amount
    trackpadAmount = "";
    updateTrackpadAmountDisplay();
    delay(200);
  }

  if (digitalRead(WIO_KEY_B) == LOW)
  {
    // Go back to WiFi screen
    currentScreen = WIFI_SCAN;
    drawWiFiScreen();
    delay(300);
  }

  if (digitalRead(WIO_KEY_C) == LOW)
  {
    // Process transaction (now requires PIN)
    processTransaction();
    delay(300);
  }
}