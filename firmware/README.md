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
