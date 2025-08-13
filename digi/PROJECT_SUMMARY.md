# DigiSave Security & Automation System

## Project Overview

DigiSave is a smart home security and automation system built with Flutter and Firebase. It leverages Seeed Studio components, including the Wio Terminal (for banking and NFC/POS features) and the Xiao ESP32S3 (for security camera and automation), to provide real-time camera streaming, feature toggling, and event logging. The system is designed for easy control and monitoring of home security and banking features from a mobile app.

## Key Features

- **Live Camera Streaming:** View real-time video from a Xiao ESP32S3 camera module directly in the app.
- **Feature Toggles:** Remotely enable or disable security features such as motion detection, night mode, time-lapse, tracking, dormancy, and calibration for each room (powered by Xiao ESP32S3).
- **Banking & NFC POS:** Integrate Seeed Studio Wio Terminal for secure banking and NFC point-of-sale (POS) transactions (optional extension).
- **Room Management:** Organize and manage multiple rooms/zones, each with its own set of features and camera stream.
- **Event Logging:** Every feature toggle (e.g., 'Buzz on') is logged to Firestore for audit/history, providing a record of all security actions.
- **History View:** Review a timeline of all feature changes and security events for transparency and troubleshooting.
- **User-Friendly UI:** Modern, intuitive interface for quick access to all controls and status indicators.

## Real-Life Applications

- **Home Security:** Monitor and control security features for different rooms, receive alerts, and review logs of all actions (using Xiao ESP32S3).
- **Office/Business Security:** Manage multiple zones, track access and feature usage, and maintain a secure environment.
- **Smart Banking & POS:** Use the Seeed Studio Wio Terminal for secure banking operations and NFC-based point-of-sale transactions, demonstrating IoT in fintech.
- **Maker Projects:** Demonstrates integration of Flutter, Firebase, Xiao ESP32S3, and Wio Terminal hardware for rapid prototyping and IoT innovation.
- **Audit & Compliance:** Event logging provides a verifiable record of all security actions, useful for compliance and incident review.

## How It Helps at Maker Faire

- **Showcases IoT Integration:** Demonstrates seamless communication between mobile apps, cloud services, and physical devices, including Seeed Studio Wio Terminal and Xiao ESP32S3.
- **Hands-On Demo:** Visitors can interact with the app, toggle features, and see real-time changes on the Xiao ESP32S3 camera, as well as try banking/NFC POS features on the Wio Terminal.
- **Inspires Innovation:** Provides a template for building custom smart home, security, or fintech solutions using open-source tools and Seeed Studio hardware.
- **Educational Value:** Highlights best practices in mobile development, cloud integration, IoT hardware, and real-time data handling.

## Summary

DigiSave empowers users to take control of their security environment with a flexible, extensible, and user-friendly platform. It bridges the gap between digital interfaces and physical security, making smart automation accessible and transparent for everyone.
