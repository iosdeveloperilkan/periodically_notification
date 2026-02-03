# GitHub Copilot System Rules for Periodically Notification

## [FLUTTER WIDGET BUILD ORDER RULE] ⭐ PRIMARY RULE

**Bu rule HER kod yazımında, HER debug işleminde KULLANILMALIDIR.**

### Widget Lifecycle Order (Swift → Flutter)

```
PHASE 1: Swift iOS Lifecycle
──────────────────────────────
1. [APP-SWIFT] DidFinishLaunching başladı
   # GitHub Copilot System Rules for Periodically Notification

   ## [FLUTTER WIDGET BUILD ORDER RULE] ⭐ PRIMARY RULE

   **Bu rule HER kod yazımında, HER debug işleminde KULLANILMALIDIR.**

   ### Widget Lifecycle Order (Swift → Flutter)

   PHASE 1: Swift iOS Lifecycle
   ──────────────────────────────
   1. [APP-SWIFT] DidFinishLaunching başladı
      └─ Firebase init, permissions, FCM token handler setup
      └─ app:didFinishLaunchingWithOptions: called

   2. [APP-SWIFT] Scene configuration talep edildi
      └─ AppDelegate.application:configurationForConnecting:options
      └─ Scene delegate atanıyor

   3. [APP-SWIFT] SceneDelegate atandı
      └─ config.delegateClass = SceneDelegate.self

   4. [APP-SWIFT] Scene willConnect başladı
      └─ SceneDelegate.scene:willConnectTo:options:
      └─ UIWindowScene oluşturuluyor


   PHASE 2: Swift UIWindow Setup (KRİTİK)
   ────────────────────────────────────────
   5. [APP-SWIFT] UIWindowScene oluşturuldu
      └─ guard let windowScene = scene as? UIWindowScene

   6. [APP-SWIFT] UIWindow oluşturuldu
      └─ let window = UIWindow(windowScene: windowScene)

   7. [APP-SWIFT] FlutterViewController set edildi ⭐⭐⭐ CRITICAL
      └─ window.rootViewController = FlutterViewController()
      └─ BU SATIR OLMAMIŞSE SİYAH EKRAN!

   8. [APP-SWIFT] UIWindow visible yapıldı
      └─ window.makeKeyAndVisible()
      └─ self.window = window


   PHASE 3: Dart Initialization (runApp)
   ──────────────────────────────────────
   9. [APP-DART] main() başladı
      └─ Dart VM başlıyor
      └─ main() function entered
      └─ FirebaseService.initialize() çalışabilir

   10. [APP-DART] runApp() tamamlandı
       └─ MaterialApp widget tree'ye girildi
       └─ Widget render phase başladı


   PHASE 4: Widget Tree Creation
   ──────────────────────────────
   11. [APP-DART] MyApp.createState() çağrıldı
       └─ StatefulWidget.createState() invoked

   12. [APP-DART] _MyAppState.initState() çağrıldı
       └─ State.initState() lifecycle method
       └─ One-time initialization happens here

   13. [APP-DART] _MyAppState.didChangeDependencies() çağrıldı
       └─ State.didChangeDependencies() called
       └─ InheritedWidget tracking


   PHASE 5: Widget Build (Render)
   ───────────────────────────────
   14. [APP-DART] _MyAppState.build() başladı
       └─ Build method entered
       └─ Widget tree created

   15. [APP-DART] _MyAppState.build() tamamlandı
       └─ Build method completed
       └─ ✅ UI GÖRÜNÜR oluyor


   PHASE 6: App Active
   ───────────────────
   16. [APP-SWIFT] Scene did become active
       └─ App foreground'a geçti
       └─ Application is now visible to user


   ### Kurallar (MANDATORY)

   ✅ **HER kodlama görevinde:**
   - Bu order'ı baştan sona kontrol et
   - Eğer log eksikse, pipeline'da sorun vardır
   - Debug işleminde önce logları oku, order'ı doğrula

   ✅ **Timeout callback'leri:**
   ```dart
   // ❌ YASAKLANMIŞ:
   onTimeout: () async {
     print('timeout');
   }

   // ✅ DOĞRU:
   onTimeout: () {
     print('timeout');  // void return, async YASAK!
   }
   ```

   ✅ **Scene/Window setup'ta:**
   - `config.delegateClass = SceneDelegate.self` mutlaka atanmalı
   - `window.rootViewController = FlutterViewController()` mutlaka set edilmeli
   - `window.makeKeyAndVisible()` mutlaka çağrılmalı
   - Biri atlanırsa = SİYAH EKRAN

   ✅ **Service integration sırası:**
   1. Swift lifecycle TAMAMLANSIN (log: "DidFinishLaunching tamamlandı")
   2. UIWindow visible OLSUN (log: "UIWindow visible yapıldı")
   3. SONRA Dart main() çalışsın (log: "main() başladı")

   ✅ **Firebase/HomeWidget init:**
   - Async timeout callback'ler void dönmeli
   - subscribeToTopic() timeout'u handle edilmeli
   - HomeWidget.setAppGroupId() timeout'u handle edilmeli

   ### Log Prefix'leri (STANDARDIZED)

   - `[APP-SWIFT]` - iOS AppDelegate / SceneDelegate lifecycle
   - `[APP-DART]` - Dart main() ve Widget lifecycle
   - `[INIT]` - Firebase / Services initialization
   - `[FCM]` - Firebase Cloud Messaging handlers
   - `[WIDGET]` - Widget-specific lifecycle (deprecated, [APP-DART] kullan)

   ### Common Issues & Solutions

   | Issue | Log Missing | Solution |
   |-------|------------|----------|
   | Siyah ekran | `[APP-SWIFT] FlutterViewController set edildi` | SceneDelegate'de `window.rootViewController = FlutterViewController()` ekle |
   | Firebase timeout | `[INIT]` logs freeze | onTimeout callback'inde `async` kaldır |
   | Scene not active | `[APP-SWIFT] Scene did become active` | windowScene'den window oluştur, makeKeyAndVisible çağır |
   | Widget not rendering | `[APP-DART] _MyAppState.build() tamamlandı` | Scaffold backgroundColor set et, body'de Center + Text |

   ---

   **Last Updated:** 3 Şubat 2026
   **Status:** ACTIVE - HER KODLAMA'DA KULLANILIYOR

   ## Applied Fixes (3 Şubat 2026)

   Aşağıda bu oturumda uyguladığımız **somut** değişiklikler ve nedenleri özetlenmiştir. Bu adımlar hata tekrarını önlemek ve yeni ekip üyelerine rehberlik etmek için kopyalanmalı/kullanılmalıdır.

   - **Dart binding initialization:** `lib/main.dart` içinde `WidgetsFlutterBinding.ensureInitialized()` eklendi. Neden: platform kanalları ve plugin erişimi `main()` içinde kullanılmadan önce binding sağlanmalı.

   - **Firebase startup order:** `main()` artık `await Firebase.initializeApp()` ve ardından `await FirebaseService.initialize()` yapıyor. Neden: Firebase API'leri, `initializeApp()` tamamlanmadan çağrılırsa `[core/no-app]` ve bağlantı hataları alınır.

   - **AppDelegate: dedicated FlutterEngine:** `ios/Runner/AppDelegate.swift` içinde bir `FlutterEngine` oluşturduk (`FlutterEngine(name: "my_engine")`), `run()` ile başlattık ve `GeneratedPluginRegistrant.register(with: engine)` ile pluginleri bu engine üzerinde kaydettik. Neden: `SceneDelegate` ile `FlutterViewController` oluşturulduğunda pluginler yüklenmemiş olabiliyordu; engine ile plugin kayıt zamanlaması garantilendi.

   - **SceneDelegate: engine ile FlutterViewController:** `SceneDelegate` artık AppDelegate'de başlatılan engine'i kullanarak `FlutterViewController(engine: engine, ...)` oluşturuyor. Neden: Bu, `MissingPluginException` ve `channel-error` (pigeon host api) problemlerini çözer.

   - **FirebaseService refactor:** `lib/services/firebase_service.dart` içinde `initialize()` statik yapıldı; `FirebaseMessaging.instance` ve `FirebaseFirestore.instance` artık lokal değişkenlerde kullanılıyor; mesaj handlerlar statik hale getirildi ve `onTimeout` callback'leri `async` olmayan void fonksiyonlara dönüştürüldü. Neden: Statik/instance karışıklığı, onTimeout içinde async kullanımı ve plugin çağrı sıralaması hatalara neden oluyordu.

   - **HomeWidget usage:** Uygulama `HomeWidget.getWidgetData()` ile widget verilerini okuyor; background/bildirim geldiğinde `HomeWidget.updateWidget()` çağrılıyor. Neden: Widget güncelleme akışını debug etmek ve local widget state'i senkronize etmek için.

   - **Cloud Function callable:** `manualSendDailyContent` callable fonksiyonu kullanıma alındı (functions/index.js). Uygulama içinde bir "Test Notification Gönder" butonu aracılığıyla fonksiyon çağrılabiliyor. Neden: Scheduler'ı beklemeden akışı manuel test etmek için.

   - **iOS rebuild talimatları:** Temiz build ve pod yenileme zorunlu kılındı: `flutter clean`, `flutter pub get`, `cd ios && pod install`, `flutter run`. Neden: Yeni native değişikliklerin (engine, plugin kayıtları) Xcode/pod tarafında derlenmesi gerekiyor.

   ## Doğrulama (Run / Log kontrolleri)

   - Başarılı başlatma: Console'da sıralı logları doğrula:
     - `[APP-SWIFT] DidFinishLaunching tamamlandı`
     - `[APP-SWIFT] UIWindow visible yapıldı` veya `[APP-SWIFT] FlutterViewController (engine ile) set edildi`
     - `flutter: [APP-DART] main() başladı`
     - `flutter: [APP-DART] Firebase initialize tamamlandı`
     - `flutter: [APP-DART] _MyAppState.build() tamamlandı`

   - Hataların OLMAMASI gerekir:
     - `Binding has not yet been initialized.`
     - `PlatformException(channel-error, Unable to establish connection on channel: "dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeCore")`
     - `MissingPluginException(No implementation found for method ...)`

   ## Hızlı Rebuild Komutları

   ```bash
   flutter clean
   flutter pub get
   cd ios
   pod install
   cd ..
   flutter run
   ```

   ## Notes
   - Eğer `MissingPluginException` devam ederse: Xcode ile `Runner.xcworkspace` açıp Product → Clean Build Folder, sonra tekrar run deneyin.


   ---
