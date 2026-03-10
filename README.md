# IDS Vault 🛡️
## 📱 App Preview
<p align="center">
  <img src="screenshots/Screenshot%202026-03-03%20123138.png" width="160" style="margin: 10px;" />
  <img src="screenshots/Screenshot%202026-03-03%20140308.png" width="160" style="margin: 10px;" />
  <img src="screenshots/Screenshot%202026-03-03%20140328.png" width="160" style="margin: 10px;" />
  <img src="screenshots/Screenshot%202026-03-05%20150223.png" width="160" style="margin: 10px;" />
  <img src="screenshots/Screenshot%202026-03-06%20201819.png" width="160" style="margin: 10px;" />
</p>

A privacy-first, zero-knowledge digital document locker designed to securely store sensitive government IDs (Aadhaar, PAN, Driver's License) completely offline.

This application was developed as a BTech Cybersecurity project by Biswajit Sahoo, focusing on mobile application security, local data encryption, and secure OS-level hardware interactions.

## 🔐 Core Security Features

* **Military-Grade Encryption:** Utilizes the AES-256 algorithm to encrypt all documents before saving them to the device's internal storage.
* **Zero-Knowledge Architecture:** 100% offline. The app connects to no external servers, APIs, or cloud backups. Your data never leaves your device.
* **Biometric Access Control:** Integrated with Android's native biometric prompt (`local_auth`) to require a fingerprint, face scan, or PIN to access the vault.
* **App Lifecycle Protection:** Actively monitors the OS lifecycle state. The app instantly locks itself and purges the navigation stack the moment it is pushed to the background or the screen turns off.
* **Scoped Storage Isolation:** Documents are saved securely within the internal Android App Sandbox (`/data/user/0/...`), making them invisible and inaccessible to third-party file managers or gallery apps.

## 🛠️ Tech Stack

* **Framework:** Flutter (Dart)
* **Encryption:** `encrypt` (AES-256)
* **Key Management:** `flutter_secure_storage` (Backed by Android Keystore System)
* **Authentication:** `local_auth` (Native biometric hardware integration)
* **UI/UX:** Material Design 3 (Dark Theme optimized)

## 🚀 Getting Started

If you are cloning this repository to build it locally, please note that you must provide your own Android signing keys.

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/Heavendart888/Ids-Vault.git](https://github.com/Heavendart888/Ids-Vault.git)

2. **Fetch dependencies:**
```bash
flutter pub get

```

3. **Security Note for Builds:** To build the release APK or AAB, you must generate your own `upload-keystore.jks` and configure the `android/key.properties` file locally. These files are intentionally excluded from this repository via `.gitignore` to prevent secret leakage.

4. **Run the app:**
```bash
flutter run

```
