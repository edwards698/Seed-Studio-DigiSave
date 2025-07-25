#include <rpcWiFi.h>
#include <TFT_eSPI.h>
#include <SPI.h>

TFT_eSPI tft = TFT_eSPI();

enum Screen
{
  WIFI_SCAN,
  PASSWORD_INPUT,
  CONNECTING,
  HOME
};
Screen currentScreen = WIFI_SCAN;

String selectedSSID = "";
String inputPassword = "";
int selectedIndex = 0;
int totalNetworks = 0;

bool useUpperCase = false; // Toggle for Shift key
bool showPassword = false; // Toggle for password visibility
bool symbolsMode = false;  // Toggle for symbols/letters mode

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
#define KEYBOARD_BG 0x1C1C    // Dark gray background
#define KEY_NORMAL 0x4A49     // Normal key color
#define KEY_PRESSED 0x5AEB    // Pressed key color (blue)
#define KEY_SPECIAL 0x39E7    // Special keys color
#define KEY_SYMBOLS 0x6B4D    // Symbols mode key color
#define TEXT_PRIMARY 0xFFFF   // White text
#define TEXT_SECONDARY 0xC618 // Light gray text
#define ACCENT_COLOR 0x5AEB   // Blue accent
#define INPUT_BG 0x2945       // Input field background

// WiFi network display constants
#define NETWORK_HEIGHT 35      // Fixed height for each network item (increased from ~26)
#define NETWORK_TEXT_SIZE 2    // Fixed text size for network names
#define MAX_VISIBLE_NETWORKS 5 // Reduced to fit bigger items

// Function prototypes
void drawWiFiScreen();
void drawAllNetworks();
void drawSingleNetwork(int index);
void drawSignalBars(int x, int y, int rssi, uint16_t color);
void handleWiFiSelection();
void handleKeyboardInput();
void connectToWiFi();
void drawKeyboard();
void updatePasswordDisplay();
void updateAllKeys();
void updateModeIndicator();
void drawConnectingScreen();
void drawHomeScreen();
void drawErrorScreen();

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
  case HOME:
    break; // Nothing more here
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
  // Smaller key dimensions
  int keyW = 22;
  int keyH = 16;
  int keyRadius = 2;
  int keySpacing = 1;
  int totalKeyboardWidth = 10 * keyW + 9 * keySpacing;
  int startX = (320 - totalKeyboardWidth) / 2;
  int startY = 85;

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
  // Update all keys when switching modes (smaller)
  int keyW = 22;
  int keyH = 16;
  int keyRadius = 2;
  int keySpacing = 1;
  int totalKeyboardWidth = 10 * keyW + 9 * keySpacing;
  int startX = (320 - totalKeyboardWidth) / 2;
  int startY = 85;

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

  // Keyboard keys - centered and smaller
  int keyW = 22;
  int keyH = 16;
  int keyRadius = 2;
  int keySpacing = 1;
  int totalKeyboardWidth = 10 * keyW + 9 * keySpacing; // 10 keys + 9 spaces
  int startX = (320 - totalKeyboardWidth) / 2;
  int startY = 85;

  for (int y = 0; y < 4; y++)
  {
    for (int x = 0; x < 10; x++)
    {
      drawSingleKey(x, y, keyW, keyH, keyRadius, startX, startY, keySpacing);
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
    currentScreen = HOME;
    drawHomeScreen();
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
    if (digitalRead(WIO_5S_PRESS) == LOW || digitalRead(WIO_KEY_B) == LOW || digitalRead(WIO_KEY_C) == LOW)
    {
      keyboardInitialized = false;
      currentScreen = PASSWORD_INPUT;
      drawKeyboard();
      delay(500);
      break;
    }
  }
}

// ────────────── Home Screen ──────────────
void drawHomeScreen()
{
  tft.fillScreen(TFT_BLACK);

  // Success icon area
  tft.fillCircle(160, 80, 40, 0x07E0); // Green circle
  tft.setTextColor(TEXT_PRIMARY, 0x07E0);
  tft.setTextSize(3);
  tft.drawString("✓", 150, 65);

  // Success message
  tft.setTextColor(0x07E0, TFT_BLACK);
  tft.setTextSize(2);
  tft.drawString("Connected!", 100, 140);

  // Connection details
  tft.setTextColor(TEXT_PRIMARY, TFT_BLACK);
  tft.setTextSize(1);
  tft.drawString("Network: " + selectedSSID, 10, 170);
  tft.drawString("IP Address: " + WiFi.localIP().toString(), 10, 185);
}