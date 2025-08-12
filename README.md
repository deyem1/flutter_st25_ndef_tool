# flutter\_st25\_ndef\_tool

A Flutter boilerplate to **read and write NDEF messages** on **STMicroelectronics ST25 (Type 5 / ISO15693)** NFC tags.
Works with standard Flutter NFC plugins, so you can extend it quickly for your own projects or demos.

> Target use-cases: quick lab tools, production PoCs, technician utilities, and internal apps that need reliable NDEF read/write on ST25 tags.

---

## Features

* 📡 Detect NFC tags and show **UID, tech/type, NDEF capability**
* 📖 **Read NDEF** messages (Text, URI, MIME records)
* ✍️ **Write NDEF** messages to supported tags
* 🔒 Graceful errors for **read-only / unformatted** tags
* 🧱 Clean, minimal UI + modular code to drop into any app
* 🧪 Simple services for unit testing & DI

---

## Supported tags

* NFC Forum **Type 5** (ISO15693) tags such as the **ST25** family (e.g. ST25DV, ST25TA, etc.).
* Phones:

  * **Android**: broad ISO15693 support (varies by device/vendor).
  * **iOS 13+**: ISO15693 supported on many devices; NDEF write support may vary by iOS version/device.

> Note: Some ST25 tags might ship unformatted for NDEF. You can still access raw blocks via platform-specific APIs, but this boilerplate focuses on **NDEF**. (Formatting to NDEF is tag-/tool-specific and outside the scope here.)

---

## Project structure

```
lib/
  main.dart
  app.dart
  features/
    nfc/
      nfc_page.dart            # UI: scan/write controls, live status
      nfc_controller.dart      # Presentation/controller layer
      nfc_service.dart         # Wrapper around plugin calls
      ndef_models.dart         # Helpers/encoders/decoders
```

---

## Quick start

### 1) Dependencies

Add the NFC + NDEF packages you prefer (these are commonly used and well-maintained):

```yaml
dependencies:
  flutter:
    sdk: flutter
  nfc_manager: ^3.3.0     # tag discovery/session
  ndef: ^0.4.2            # build/parse NDEF records
```

Run:

```bash
flutter pub get
```

### 2) Android setup

`android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...>
  <uses-permission android:name="android.permission.NFC"/>
  <uses-feature android:name="android.hardware.nfc" android:required="true"/>

  <application ...>
    <!-- No special foreground dispatch needed: handled by plugin -->
  </application>
</manifest>
```

* `minSdkVersion` 21 or higher is recommended.

### 3) iOS setup

Open `ios/Runner.xcworkspace` in Xcode:

* **Signing & Capabilities** → add **Near Field Communication Tag Reading** capability.
* In your **.entitlements** file, add:

  * `com.apple.developer.nfc.readersession.formats = [ "NDEF", "TAG" ]` (include **TAG** for ISO15693).
* In **Info.plist** add:

  * `NFCReaderUsageDescription` (string explaining why you need NFC).

---

## Usage (boilerplate snippets)

### Check availability

```dart
import 'package:nfc_manager/nfc_manager.dart';

Future<bool> isNfcAvailable() async {
  return await NfcManager.instance.isAvailable();
}
```

### Read NDEF

```dart
import 'package:nfc_manager/nfc_manager.dart';
import 'package:ndef/ndef.dart' as ndef;

Future<void> readNdef() async {
  await NfcManager.instance.startSession(onDiscovered: (tag) async {
    try {
      final ndefTag = Ndef.from(tag);
      if (ndefTag == null) {
        throw Exception('Tag is not NDEF-formattable or NDEF-capable.');
      }

      final message = await ndefTag.read();
      final records = message.records
          .map((r) => ndef.NDEFRecord.fromByteList(r.payload))
          .toList();

      // TODO: parse/display records in UI
      // e.g., handle Text, URI, MIME, etc.

      await NfcManager.instance.stopSession();
    } catch (e) {
      await NfcManager.instance.stopSession(errorMessage: e.toString());
    }
  });
}
```

### Write NDEF (Text example)

```dart
import 'package:nfc_manager/nfc_manager.dart';
import 'package:ndef/ndef.dart' as ndef;

Future<void> writeText(String text, {String lang = 'en'}) async {
  final record = ndef.TextRecord(text, language: lang);
  final msg = ndef.NDEFMessage([record]);

  await NfcManager.instance.startSession(onDiscovered: (tag) async {
    try {
      final ndefTag = Ndef.from(tag);
      if (ndefTag == null) {
        throw Exception('Tag is not NDEF-capable.');
      }
      if (!ndefTag.isWritable) {
        throw Exception('Tag is read-only.');
      }

      // Convert `ndef` package message into plugin format:
      final pluginMessage = NdefMessage(msg.records.map((r) {
        final bytes = r.encode();
        // Basic mapping: treat encoded NDEF as a single MIME or Text record.
        // For richer mappings, build specific NdefRecord.* via plugin API.
        return NdefRecord.createText(text); // simple case
      }).toList());

      await ndefTag.write(pluginMessage);
      await NfcManager.instance.stopSession();
    } catch (e) {
      await NfcManager.instance.stopSession(errorMessage: e.toString());
    }
  });
}
```

### Write NDEF (URI example)

```dart
Future<void> writeUri(String url) async {
  await NfcManager.instance.startSession(onDiscovered: (tag) async {
    try {
      final ndefTag = Ndef.from(tag);
      if (ndefTag == null) throw Exception('Tag not NDEF-capable.');
      if (!ndefTag.isWritable) throw Exception('Tag is read-only.');

      final message = NdefMessage([
        NdefRecord.createUri(Uri.parse(url)),
      ]);

      await ndefTag.write(message);
      await NfcManager.instance.stopSession();
    } catch (e) {
      await NfcManager.instance.stopSession(errorMessage: e.toString());
    }
  });
}
```

> Tip (iOS): keep the phone steady on the tag until the session completes.
> Tip (Android): some OEMs throttle ISO15693 polling; a brief delay before writing can help.

---

## UI wiring (example)

Bind these actions to buttons on a simple page:

```dart
ElevatedButton(
  onPressed: () async {
    if (!await isNfcAvailable()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NFC not available on this device.')),
      );
      return;
    }
    await readNdef();
  },
  child: const Text('Read NDEF'),
),

ElevatedButton(
  onPressed: () async {
    if (!await isNfcAvailable()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NFC not available on this device.')),
      );
      return;
    }
    await writeText('minpres=1.0,maxpres=2.0,maxdiff=0.5,minlocpres=0.9,locdur=30s');
  },
  child: const Text('Write NDEF (Config Text)'),
),
```

---

## Roadmap

* [ ] Presets for **ST25 config payloads** (e.g., engineering key–value strings)
* [ ] Record inspectors (Text, URI, MIME, External Type)
* [ ] Optional **raw ISO15693** helpers (read blocks / write blocks) for advanced ST25 use
* [ ] Tag memory size & lock status UI
* [ ] Example: **config writer** for your pressure/lockout parameters

---

## Troubleshooting

* **`Tag is not NDEF-capable`**
  The tag is unformatted or only supports raw ISO15693. Use ST tools or platform APIs to format it to NDEF.
* **Write fails on iOS**
  Ensure the **NFC capability** is added and you’re holding the device on the tag until the session completes.
* **Android write succeeds but content not visible**
  Some apps filter certain record types. Verify with a “raw” NDEF inspector or your own reader.

---

## Contributing

1. Fork the repo: `https://github.com/deyem1/flutter_st25_ndef_tool`
2. Create a feature branch: `git checkout -b feat/better-ndef-ui`
3. Commit changes: `git commit -m "feat: add record inspector"`
4. Push and open a PR.

Issues and PRs welcome—please include device model, OS version, tag type, and logs where relevant.

---

## Licence

MIT © Abdulrahman Adeyemi

---

## Credits

* Community packages: `nfc_manager`, `ndef`
* STMicroelectronics for the **ST25** ecosystem (docs, app notes, dev kits)

---
From me to you
