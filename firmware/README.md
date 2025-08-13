# DigiSave Banking & Security System

## Where to Buy Components

You can purchase the main hardware for DigiSave from Seeed Studio or their official distributors:

- **Seeed Studio Xiao ESP32S3:** [Buy from Seeed Studio](https://www.seeedstudio.com/XIAO-ESP32S3-p-5620.html)
- **Seeed Studio Wio Terminal:** [Buy from Seeed Studio](https://www.seeedstudio.com/Wio-Terminal-p-4509.html)

Other components (e.g., sensors, relays, power supplies) can be found on Seeed Studio, Amazon, or your local electronics supplier.

## Download the App

You can download the DigiSave app for your device here:

- **Download the APK** [Here](https://www.dropbox.com/scl/fo/axe60a9auwhj9i7py7ba3/AB-713sxKs7kODNP4PAcmEU?rlkey=jzn2t8zk9k257u6u9aoaqulx1&st=w4b7ny4u&dl=0)

If you are a developer or tester, you can also build and run the app from source using Flutter (see the main README for instructions).

## Technology Stack Overview

DigiSave combines modern software and hardware technologies to deliver a robust, real-time smart home security and automation platform. Below is an overview of the technology stack and how each component is used in the project.

---

## Software Technologies

- **Flutter**

  - Cross-platform UI toolkit for building the DigiSave mobile app (Android/iOS).
  - Enables a modern, responsive, and beautiful user interface.

- **Dart**

  - Programming language for Flutter app logic, state management, and UI.

- **Firebase**

  - Cloud backend for authentication, real-time database (Firestore), and data sync.

- **Firestore**

  - NoSQL cloud database for storing feature states, logs, and history.
  - Enables real-time updates and audit trails for all security and banking actions.

- **Google Fonts**

  - Provides modern, readable typography for the app UI.

- **HTTP/MJPEG Streaming**

  - Used to stream live video from the Xiao ESP32S3 camera to the app.

- **Provider/State Management** (if used)
  - Manages app state, feature toggles, and UI updates.

---

## Hardware Technologies

- **Seeed Studio Xiao ESP32S3**

  - Microcontroller for camera streaming, security feature toggling, and automation.
  - Connects to the DigiSave app via WiFi for real-time control and monitoring.

- **Seeed Studio Wio Terminal**
  - IoT device for banking, NFC, and POS integration.
  - Demonstrates secure transactions and NFC-based payments in a smart home context.

---

## How It All Works Together

- The DigiSave app (Flutter/Dart) communicates with Firebase/Firestore to store and retrieve feature states, logs, and user actions.
- The Xiao ESP32S3 streams live video and responds to feature toggles (motion detection, night mode, etc.) sent from the app.
- The Wio Terminal enables secure banking and NFC POS features, with all actions logged to Firestore for transparency.
- All components are designed to be modular, extensible, and easy to integrate for makers, students, and professionals.

---

## Why This Stack?

- **Cross-Platform:** Flutter allows a single codebase for both Android and iOS.
- **Real-Time:** Firestore and HTTP streaming enable instant feedback and control.
- **IoT Ready:** Seeed Studio hardware is affordable, reliable, and well-supported in the maker community.
- **Open Source:** All major components are open source or have generous free tiers for prototyping.

---

## Getting Started with PlatformIO & Hardware

### 1. PlatformIO Setup (macOS, Windows, Linux)

PlatformIO is a modern development environment for embedded systems. It works as a VS Code extension or standalone IDE.

#### **Install PlatformIO**

- **VS Code Extension:**
  1. Install [Visual Studio Code](https://code.visualstudio.com/).
  2. Go to Extensions (Ctrl+Shift+X or Cmd+Shift+X) and search for "PlatformIO IDE". Install it.
- **Standalone:**
  - Download from [platformio.org](https://platformio.org/install) and follow the instructions for your OS.

#### **Clone the Firmware Repo**

```sh
git clone https://github.com/yourusername/DigiSave.git
cd DigiSave/firmware
```

#### **Open the Project**

- Open the `firmware` folder in VS Code (or PlatformIO IDE).

#### **Install Dependencies**

- PlatformIO will auto-install libraries on first build. If not, click the PlatformIO icon and select "Build" or run:

```sh
pio run
```

### 2. Building & Uploading Firmware

#### **Wio Terminal**

- Connect your Wio Terminal via USB.
- In PlatformIO, select the correct serial port (check PlatformIO bottom bar or use `pio device list`).
- Click "Upload" (arrow icon) or run:

```sh
pio run --target upload
```

#### **Seeed Studio Xiao ESP32S3**

- Connect your Xiao ESP32S3 via USB (double-tap reset if needed for bootloader mode).
- Select the correct board environment in `platformio.ini` (e.g., `[env:xiao_esp32s3]`).
- Upload as above.

#### **Arduino Boards**

- Plug in your Arduino (Uno, Mega, etc.).
- Select the right board in `platformio.ini` (e.g., `[env:uno]`).
- Upload as above.

### 3. Serial Monitor

- To view debug output, use PlatformIO's Serial Monitor:

```sh
pio device monitor
```

- Or click the plug icon in PlatformIO.

### 4. Troubleshooting

- **macOS:** You may need to install drivers for Seeed/Arduino boards. See [Seeed Wiki](https://wiki.seeedstudio.com/Wio-Terminal-Getting-Started/) or [Arduino drivers](https://www.arduino.cc/en/Guide/DriverInstallation).
- **Windows:** Drivers usually auto-install, but check Device Manager if not.
- **Linux:** Add your user to the `dialout` group:

```sh
sudo usermod -a -G dialout $USER
```

Then log out and back in.

---

## Example PlatformIO Commands

- **Build:** `pio run`
- **Upload:** `pio run --target upload`
- **Monitor:** `pio device monitor`
- **Clean:** `pio run --target clean`

---

## Hardware Quick Start

- **Wio Terminal:**
  - Plug in via USB, upload firmware, and follow on-screen instructions.
- **Xiao ESP32S3:**
  - Plug in, upload, and use the DigiSave app for camera/IoT features.
- **Arduino:**
  - Plug in, upload, and use as per your custom project needs.

For more details, see the main project documentation and code comments.

---

## Get Involved

- Fork this repo, try the app, and connect your own ESP32S3 or Wio Terminal!
- Contributions, issues, and feature requests are welcome.

---

For more details, see the main project documentation and code comments.
