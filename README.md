# Monthly Flow

แอปรายรับรายจ่าย Flutter แบบออฟไลน์ตาม [Figma](https://www.figma.com/design/Fn32gcPn7UkzoL0z6jB5tA) ใช้ SQLite ในเครื่อง ไม่มี API หรือบัญชีผู้ใช้

เวอร์ชันปัจจุบัน: **1.0.0+1**

## 1. การติดตั้งและรันโปรเจกต์

### สิ่งที่ต้องติดตั้ง

- [Git](https://git-scm.com/downloads)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) รุ่น Stable ที่มาพร้อม Dart 3.7 ขึ้นไป
- Android Studio และ Android SDK สำหรับ Android
- Xcode และ CocoaPods สำหรับ iOS (ใช้ได้เฉพาะ macOS)

ตรวจสอบความพร้อมของเครื่อง:

```bash
flutter doctor -v
```

ควรแก้รายการที่มีเครื่องหมายกากบาท โดยเฉพาะ Android toolchain, Xcode และ Android SDK licenses ก่อนดำเนินการต่อ

### ดาวน์โหลดและติดตั้ง dependencies

```bash
git clone https://github.com/monthus2543/monthly_flow.git
cd monthly_flow
flutter pub get
```

> Repository เป็น Private ผู้ดาวน์โหลดต้องมีสิทธิ์เข้าถึงและล็อกอิน GitHub ก่อน

### เลือกอุปกรณ์และรันแอป

เปิด Android Emulator, iOS Simulator หรือเชื่อมต่อโทรศัพท์ที่เปิด Developer Mode แล้วตรวจสอบอุปกรณ์:

```bash
flutter devices
```

รันบนอุปกรณ์ตัวแรกที่พบ:

```bash
flutter run
```

หรือระบุ Device ID ที่ได้จาก `flutter devices`:

```bash
flutter run -d DEVICE_ID
```

ตัวอย่าง:

```bash
flutter run -d emulator-5554
flutter run -d ios
```

ระหว่างพัฒนากด `r` ใน Terminal เพื่อ Hot Reload หรือกด `R` เพื่อ Hot Restart

### รันผ่าน Android Studio หรือ VS Code

1. เปิดโฟลเดอร์ `monthly_flow`
2. รอให้ IDE โหลด Flutter packages ให้เสร็จ
3. เลือก Emulator, Simulator หรือโทรศัพท์จาก Device Selector
4. เปิด `lib/main.dart` แล้วกด Run หรือ Debug

### ตรวจสอบโค้ด

```bash
flutter analyze
flutter test
```

## 2. การ Build แอป iOS/Android

เวอร์ชันแอปกำหนดใน `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

- `1.0.0` คือ Version Name ที่ผู้ใช้เห็น
- `1` คือ Build Number/Version Code ซึ่งต้องเพิ่มทุกครั้งที่ส่งรุ่นใหม่ขึ้น Store

### Android: Build APK

```bash
flutter clean
flutter pub get
flutter build apk --release
```

ไฟล์ที่ได้:

```text
build/app/outputs/flutter-apk/app-release.apk
```

บน Windows สามารถใช้สคริปต์ของโปรเจกต์:

```powershell
.\build-apk.ps1 -VersionType hotfix
```

สคริปต์รองรับการอัปเดตเวอร์ชันอัตโนมัติ 3 แบบ:

| VersionType | ตัวอย่าง | ใช้เมื่อ |
| --- | --- | --- |
| `major` | `1.0.0 → 2.0.0` | เปลี่ยนแปลงใหญ่หรือไม่รองรับรูปแบบเดิม |
| `feature` | `1.0.0 → 1.1.0` | เพิ่มความสามารถหรือฟังก์ชันใหม่ |
| `hotfix` | `1.0.0 → 1.0.1` | แก้บั๊กหรือปรับปรุงเล็กน้อย |

Build Number หลังเครื่องหมาย `+` จะเพิ่มขึ้น 1 ทุกครั้ง เช่น `1.0.0+1 → 1.0.1+2` หาก build ไม่สำเร็จ สคริปต์จะคืนค่าเวอร์ชันเดิมให้อัตโนมัติ

เพิ่มเวอร์ชันมากกว่า 1 ระดับใน Build เดียวได้ด้วย `VersionIncrement` เช่น feature +2:

```powershell
.\build-apk.ps1 -Mode release -VersionType feature -VersionIncrement 2
```

ตัวอย่าง `1.4.0+5 → 1.6.0+6` โดย Build Number เพิ่มเพียง 1 ครั้ง

### Git Branch ตามประเภทเวอร์ชัน

ทุกงานใช้ branch ใหม่จาก `main` โดยตั้งชื่อตามประเภทและเวอร์ชัน:

```text
major/v2.0.0
feature/v1.1.0
hotfix/v1.0.1
```

หลังแก้ไขและ build เสร็จ ให้กลับมาที่ `main` แล้วใช้สคริปต์ publish:

```powershell
.\publish-git.ps1 -VersionType feature -Message "Add new dashboard feature"
```

สคริปต์จะอ่านเวอร์ชันจาก `pubspec.yaml`, สร้าง branch ใหม่, commit การเปลี่ยนแปลงทั้งหมด และ push ขึ้น `origin` จากนั้นให้สร้าง Pull Request เพื่อ review และ merge เข้า `main`

ตัวอย่างประเภทอื่น:

```powershell
.\publish-git.ps1 -VersionType major -Message "Release version 2"
.\publish-git.ps1 -VersionType hotfix -Message "Fix amount input"
```

Branch ชื่อเดิมจะไม่ถูกนำกลับมาใช้ซ้ำ หากต้องอัปเดตเวอร์ชันเดิมอีกครั้งควรเพิ่มเลขเวอร์ชันก่อน publish

สคริปต์จะสร้างไฟล์:

```text
build\app\outputs\flutter-apk\monthly-flow-release-1.0.0.apk
```

หากต้องการ Debug APK:

```powershell
.\build-apk.ps1 -Mode debug -VersionType hotfix
```

### Android: Build App Bundle สำหรับ Google Play

```bash
flutter build appbundle --release
```

ไฟล์ที่ได้:

```text
build/app/outputs/bundle/release/app-release.aab
```

> ปัจจุบัน `android/app/build.gradle` ใช้ debug signing สำหรับ release build เพื่อให้ build ทดสอบได้ทันที ก่อนอัปโหลด Google Play ต้องสร้าง release keystore และเปลี่ยน `signingConfig` ตามคู่มือ [Sign the app](https://docs.flutter.dev/deployment/android#sign-the-app)

GitHub Actions ใช้คีย์ทดสอบเดิมจาก repository secret `ANDROID_DEBUG_KEYSTORE_BASE64` โดยตรวจ SHA-1 ให้ตรงกับที่ลงทะเบียนใน Firebase ก่อน build ทั้ง debug และ release หากไม่มี secret จะหยุด build แทนการสร้างคีย์ใหม่ที่ Google Login ไม่รู้จัก ห้ามใส่ไฟล์ keystore หรือค่า secret ลงใน Git

หาก Google Login ใช้ได้ในเครื่องแต่ใช้ไม่ได้ใน APK จาก GitHub ให้ตรวจลายเซ็นของ **APK ที่ติดตั้งจริง** ด้วย `apksigner verify --print-certs` แล้วเทียบกับ Firebase > Project settings > Android app > SHA certificate fingerprints การเพิ่ม SHA ของ APK เดิมใน Firebase ไม่ต้องลบข้อมูลหรือติดตั้งแอปใหม่

เมื่อต่อโทรศัพท์ผ่าน USB สามารถติดตั้งแอปด้วย:

```bash
flutter install
```

หรือ:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### iOS: เตรียมโปรเจกต์

การ build iOS ต้องทำบน **macOS ที่ติดตั้ง Xcode** เท่านั้น

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
```

หากยังไม่มี CocoaPods:

```bash
sudo gem install cocoapods
```

### iOS: รันบน Simulator

```bash
open -a Simulator
flutter run -d ios
```

### iOS: Build โดยไม่เซ็นชื่อ

เหมาะสำหรับตรวจสอบว่า source สามารถ compile ได้:

```bash
flutter build ios --release --no-codesign
```

ไฟล์ที่ได้:

```text
build/ios/iphoneos/Runner.app
```

### iOS: Build IPA สำหรับ TestFlight/App Store

1. เปิด workspace ด้วยคำสั่ง:

   ```bash
   open ios/Runner.xcworkspace
   ```

2. ใน Xcode เลือก **Runner → Signing & Capabilities**
3. เลือก Apple Developer Team และตั้ง Bundle Identifier ที่ไม่ซ้ำ
4. ตรวจสอบ Certificate และ Provisioning Profile
5. Build IPA:

   ```bash
   flutter build ipa --release
   ```

ไฟล์ที่ได้:

```text
build/ios/ipa/*.ipa
```

อัปโหลด IPA ผ่าน Xcode Organizer หรือแอป Transporter ได้

### การแก้ปัญหาเบื้องต้น

หาก Flutter หรือ dependencies มีปัญหา:

```bash
flutter clean
flutter pub get
flutter doctor -v
```

ยอมรับ Android licenses:

```bash
flutter doctor --android-licenses
```

หาก CocoaPods มีปัญหา:

```bash
cd ios
rm -rf Pods Podfile.lock
pod repo update
pod install
cd ..
```

## สิ่งที่ทำแล้ว

- Splash แสดงระหว่างเปิดฐานข้อมูล และหน้าลองใหม่เมื่อเปิดไม่สำเร็จ
- Dashboard สรุปยอดตามเดือน กราฟรายรับรายจ่าย 6 เดือน และรายการล่าสุด
- เพิ่ม แก้ไข และลบรายการ พร้อมตรวจฟอร์มและยืนยันการลบ
- ค้นหาและกรองรายการตามเดือนและประเภท
- สถิติรายหมวดและค่าเฉลี่ยต่อวัน
- ธีมมืด เก็บการเลือกเดือนและธีมในเครื่อง คัดลอก CSV และล้างรายการหลังยืนยัน
- เก็บจำนวนเงินเป็นสตางค์แบบจำนวนเต็ม เพื่อเลี่ยงความคลาดเคลื่อนของทศนิยม
- ตั้งงบประมาณรายเดือน ดูสถานะใช้ไป/เกินงบ และแสดงบน Dashboard
- รายการประจำ เป้าหมายการออม บิลเตือน และศูนย์วางแผนการเงิน
- หลายบัญชี/กระเป๋าเงิน พร้อมยอดคงเหลือและการโอนระหว่างบัญชี
- เพิ่ม แก้ไข และซ่อนหมวดหมู่เอง รวมถึงรายการโปรดและสร้างรายการซ้ำด้วยการกดค้าง
- แนบรูปใบเสร็จ ส่งออก/นำเข้าไฟล์สำรอง JSON และโหมดซ่อนจำนวนเงิน

## ขอบเขตของรุ่นเริ่มต้น

แอปยังคงทำงานแบบออฟไลน์และไม่มีบัญชีผู้ใช้ การสำรองข้อมูลเป็นไฟล์ JSON ที่ผู้ใช้เลือกแชร์หรือเก็บเอง ยังไม่มี cloud sync ข้ามเครื่อง การเตือนบิลเป็นรายการเตือนภายในแอปและยังไม่สร้าง system notification เมื่อแอปปิด

## โครงสร้าง

- `lib/main.dart` เริ่มแอป ธีม และการเปิดฐานข้อมูล
- `lib/database/` จัดการ SQLite และ migration
- `lib/repositories/` อ่านและบันทึกข้อมูลผ่าน repository
- `lib/models/` โมเดลรายการและหมวดหมู่
- `lib/state/` state ของแอปและค่าตั้งต้น
- `lib/screens/` หน้าจอแต่ละหน้า
- `lib/widgets/` widget ที่ใช้ร่วมกันและกราฟ
- `lib/l10n/languages/` ข้อความภาษาไทยและอังกฤษ

## ตรวจสอบหลังติดตั้ง

รัน `flutter analyze`, `flutter test` และ `flutter run` บนเครื่องที่มี Flutter SDK จากนั้นลองเพิ่มรายรับและรายจ่าย เปลี่ยนเดือน แก้ไขรายการ ปิดเปิดแอป และตรวจว่าข้อมูลยังอยู่
