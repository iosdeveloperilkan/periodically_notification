import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'services/firebase_service.dart';
import 'package:home_widget/home_widget.dart';

void appLog(String message) {
  print('[APP-DART] $message');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appLog('main() başladı');
  try {
    appLog('Firebase initialize başlanıyor...');
    await Firebase.initializeApp();
    appLog('Firebase initialize tamamlandı');
    
    await FirebaseService.initialize();
    appLog('FirebaseService setup tamamlandı');
    
    runApp(const MyApp());
    appLog('runApp() tamamlandı');
  } catch (e, st) {
    appLog('ERROR runApp: $e');
    appLog('Stack: $st');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() {
    appLog('MyApp.createState() çağrıldı');
    return _MyAppState();
  }
}

class _MyAppState extends State<MyApp> {
  String widgetTitle = 'Günün İçeriği';
  String widgetBody = 'Yükleniyor...';
  String widgetUpdatedAt = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    appLog('_MyAppState.initState() çağrıldı');
    _loadWidgetData();
  }

  Future<void> _loadWidgetData() async {
    appLog('Widget data yükleniyor...');
    try {
      final title = await HomeWidget.getWidgetData<String>('widget_title', defaultValue: 'Günün İçeriği');
      final body = await HomeWidget.getWidgetData<String>('widget_body', defaultValue: 'Veri bekleniyor...');
      final updatedAt = await HomeWidget.getWidgetData<String>('widget_updatedAt', defaultValue: '');
      
      appLog('Widget title: $title');
      appLog('Widget body: $body');
      appLog('Widget updatedAt: $updatedAt');
      
      setState(() {
        widgetTitle = title ?? 'Günün İçeriği';
        widgetBody = body ?? 'Veri bekleniyor...';
        widgetUpdatedAt = updatedAt ?? '';
        isLoading = false;
      });
      appLog('Widget verileri setState ile güncellendi');
    } catch (e) {
      appLog('ERROR Widget data yükleme: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _sendTestNotification() async {
    appLog('Test notification gönderiliyor...');
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('manualSendDailyContent')
          .call();
      
      appLog('✅ Test notification gönderildi: ${result.data}');
      
      // Veriyi yenile
      await Future.delayed(const Duration(seconds: 1));
      _loadWidgetData();
    } catch (e) {
      appLog('❌ Test notification hatası: $e');
    }
  }

  @override
  void didChangeDependencies() {
    appLog('_MyAppState.didChangeDependencies() çağrıldı');
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    appLog('_MyAppState.build() başladı');
    try {
      final app = MaterialApp(
        title: 'Periodically Notification',
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Günün İçeriği'),
            backgroundColor: Colors.blue,
          ),
          backgroundColor: Colors.white,
          body: Center(
            child: isLoading
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        'Widget verileri yükleniyor...',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widgetTitle,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              widgetBody,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.black54,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (widgetUpdatedAt.isNotEmpty)
                            Text(
                              'Güncelleme: $widgetUpdatedAt',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loadWidgetData,
                            child: const Text('Verileri Yenile'),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _sendTestNotification,
                            icon: const Icon(Icons.send),
                            label: const Text('Test Notification Gönder'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      );
      appLog('_MyAppState.build() tamamlandı');
      return app;
    } catch (e, st) {
      appLog('ERROR _MyAppState.build: $e');
      appLog('Stack trace: $st');
      return MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Error: $e')),
        ),
      );
    }
  }

  @override
  void dispose() {
    appLog('_MyAppState.dispose() çağrıldı');
    super.dispose();
  }
}
