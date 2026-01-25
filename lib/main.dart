import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:home_widget/home_widget.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize Firebase Service (FCM, topic subscription)
  await FirebaseService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Periodically Notification',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = 'Initializing...';
  String? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _loadWidgetStatus();
  }

  Future<void> _loadWidgetStatus() async {
    try {
      // Check if widget has data
      final title = await HomeWidget.getWidgetData<String>('widget_title', defaultValue: '');
      final updatedAt = await HomeWidget.getWidgetData<String>('widget_updatedAt', defaultValue: '');
      
      setState(() {
        if (title != null && title.isNotEmpty) {
          _status = 'Widget is active';
          _lastUpdate = updatedAt;
        } else {
          _status = 'Waiting for daily content...';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Daily Widget'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              const Icon(
                Icons.notifications_active,
                size: 64,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 24),
              Text(
                _status,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (_lastUpdate != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Last update: ${_formatDate(_lastUpdate!)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _loadWidgetStatus,
                    child: const Text('Refresh Status'),
                  ),
                  ElevatedButton(
                    onPressed: _testManualSend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Test Send'),
                  ),
                  ElevatedButton(
                    onPressed: _testWidgetData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Test Widget'),
                  ),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _testManualSend() async {
    try {
      setState(() {
        _status = 'Sending test notification...';
      });

      print('=== TEST MANUAL SEND START ===');
      print('Region: us-central1');
      print('Function: manualSendDailyContent');
      
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      
      print('Calling function...');
      // Add timeout
      final result = await functions
          .httpsCallable('manualSendDailyContent')
          .call()
          .timeout(
            const Duration(seconds: 60), // Increased timeout
            onTimeout: () {
              print('=== TIMEOUT ERROR ===');
              throw Exception('Request timeout after 60 seconds. Check:\n'
                  '1. Internet connection\n'
                  '2. Cloud Function is deployed: firebase deploy --only functions\n'
                  '3. Function region matches (us-central1)');
            },
          );

      print('=== FUNCTION CALL SUCCESS ===');
      print('Result: ${result.data}');

      setState(() {
        _status = 'Test sent successfully! Message ID: ${result.data['messageId'] ?? 'N/A'}';
      });

      // Refresh widget status after a delay
      Future.delayed(const Duration(seconds: 2), () {
        _loadWidgetStatus();
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Success: ${result.data}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('=== TEST MANUAL SEND ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('==============================');
      
      String errorMessage = 'Error: $e';
      
      // More user-friendly error messages
      if (e.toString().contains('UNAVAILABLE')) {
        errorMessage = 'Cloud Functions unavailable. Check:\n'
            '1. Internet connection\n'
            '2. Firebase project settings\n'
            '3. Function deployment: firebase deploy --only functions';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timeout. Check:\n'
            '1. Internet connection\n'
            '2. Cloud Function is deployed\n'
            '3. Function region matches (us-central1)';
      } else if (e.toString().contains('NOT_FOUND') || e.toString().contains('not-found')) {
        if (e.toString().contains('No unsent item found')) {
          errorMessage = 'No content available to send.\n\n'
              'Add items to Firestore:\n'
              '1. Go to Firebase Console > Firestore\n'
              '2. Add document to daily_items collection:\n'
              '   - order: (next number)\n'
              '   - title: "Your title"\n'
              '   - body: "Your content"\n'
              '   - sent: false\n'
              '3. Update daily_state/current:\n'
              '   - nextOrder: (same as order)';
        } else {
          errorMessage = 'Function not found. Deploy it:\n'
              'firebase deploy --only functions';
        }
      }
      
      setState(() {
        _status = errorMessage;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _testWidgetData() async {
    try {
      print('=== TEST WIDGET DATA START ===');
      
      // Test: Manually save widget data
      print('Saving widget_title...');
      await HomeWidget.saveWidgetData<String>(
        'widget_title',
        'Test Başlık',
      );
      print('✓ widget_title saved');

      print('Saving widget_body...');
      await HomeWidget.saveWidgetData<String>(
        'widget_body',
        'Bu bir test içeriğidir. Widget\'ta görünmeli.',
      );
      print('✓ widget_body saved');

      print('Saving widget_updatedAt...');
      await HomeWidget.saveWidgetData<String>(
        'widget_updatedAt',
        DateTime.now().toIso8601String(),
      );
      print('✓ widget_updatedAt saved');

      // Verify data was saved by reading it back from SharedPreferences
      print('=== VERIFYING SAVED DATA ===');
      final savedTitle = await HomeWidget.getWidgetData<String>('widget_title', defaultValue: '');
      final savedBody = await HomeWidget.getWidgetData<String>('widget_body', defaultValue: '');
      final savedUpdatedAt = await HomeWidget.getWidgetData<String>('widget_updatedAt', defaultValue: '');
      
      print('✅ Verified widget_title in storage: $savedTitle');
      print('✅ Verified widget_body in storage: $savedBody');
      print('✅ Verified widget_updatedAt in storage: $savedUpdatedAt');
      print('=== VERIFICATION COMPLETE ===');

      // Update widget
      print('Updating widget...');
      print('Using qualifiedAndroidName: com.example.periodicallynotification.widget.DailyWidgetProvider');
      await HomeWidget.updateWidget(
        name: 'DailyWidget',
        iOSName: 'DailyWidget',
        androidName: 'DailyWidgetProvider',
        qualifiedAndroidName: 'com.example.periodicallynotification.widget.DailyWidgetProvider',
      );
      print('✓ Widget update called');

      setState(() {
        _status = 'Test data saved to widget!';
      });

      print('=== TEST WIDGET DATA SUCCESS ===');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Widget verisi kaydedildi! Ana ekrana widget ekleyin.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Refresh status
      Future.delayed(const Duration(seconds: 1), () {
        _loadWidgetStatus();
      });
    } catch (e, stackTrace) {
      print('=== TEST WIDGET DATA ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('==============================');
      
      setState(() {
        _status = 'Widget test error: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Widget error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }
}
