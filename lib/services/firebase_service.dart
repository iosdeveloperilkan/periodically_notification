import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:async';

/// Firebase Messaging Service
/// Handles FCM topic subscription and message handling
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const String _topic = 'daily_widget_all';
  static const String _widgetTitleKey = 'widget_title';
  static const String _widgetBodyKey = 'widget_body';
  static const String _widgetItemIdKey = 'widget_itemId';
  static const String _widgetUpdatedAtKey = 'widget_updatedAt';

  /// Initialize Firebase and subscribe to topic
  Future<void> initialize() async {
    try {
      // Request notification permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('User granted provisional notification permission');
      } else {
        print('User declined or has not accepted notification permission');
      }

      // Get FCM token (with retry logic)
      String? token;
      try {
        token = await _messaging.getToken();
        print('FCM Token: $token');
      } catch (e) {
        print('Warning: Could not get FCM token: $e');
        print('This might be due to network issues or Google Play Services');
        // Continue anyway - topic subscription might still work
      }

      // Subscribe to topic (with error handling)
      try {
        await _messaging.subscribeToTopic(_topic);
        print('Subscribed to topic: $_topic');
      } catch (e) {
        print('Warning: Could not subscribe to topic: $e');
        // Continue anyway - app can still receive messages if token is valid
      }

      // Set up message handlers
      _setupMessageHandlers();

      // Initialize home_widget
      await HomeWidget.setAppGroupId('group.com.siyazilim.periodicallynotification');
    } catch (e) {
      print('Error initializing Firebase: $e');
    }
  }

  /// Set up FCM message handlers
  void _setupMessageHandlers() {
    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCM_WIDGET] Foreground message received: ${message.messageId}');
      _handleMessage(message);
    });

    // Background message handler (must be top-level function)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Notification tap handler (when app is in background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[FCM_WIDGET] Notification tapped: ${message.messageId}');
      _handleMessage(message);
    });

    // Check if app was opened from a notification (when app was terminated)
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('[FCM_WIDGET] App opened from notification: ${message.messageId}');
        _handleMessage(message);
      }
    });
  }

  /// Handle incoming FCM message
  Future<void> _handleMessage(RemoteMessage message) async {
    try {
      print('[FCM_WIDGET] === MESSAGE HANDLER START ===');
      print('[FCM_WIDGET] Message ID: ${message.messageId}');
      print('[FCM_WIDGET] Message Data: ${message.data}');
      
      final data = message.data;
      final messageType = data['type'];
      print('[FCM_WIDGET] Message Type: $messageType');
      
      // Check if this is a daily widget message
      final isDailyWidget = messageType == 'DAILY_WIDGET' || messageType == 'DAILY_WIDGET_UPDATE';
      print('[FCM_WIDGET] Is Daily Widget: $isDailyWidget');
      
      if (isDailyWidget) {
        print('[FCM_WIDGET] ✅ Processing DAILY_WIDGET message');
        
        final itemId = data['itemId'];
        final docPath = data['docPath'];
        
        print('[FCM_WIDGET] ItemId: $itemId');
        print('[FCM_WIDGET] DocPath: $docPath');
        
        // Fetch full content from Firestore if docPath is provided
        Map<String, dynamic> widgetData = {
          'title': data['title'] ?? '',
          'body': data['body'] ?? '',
          'itemId': itemId ?? '',
          'updatedAt': data['updatedAt'] ?? DateTime.now().toIso8601String(),
        };
        
        print('[FCM_WIDGET] Initial widgetData: title=${widgetData['title']}, body=${widgetData['body']}');

        // If docPath is provided, fetch from Firestore for complete data
        if (docPath != null && docPath.isNotEmpty) {
          print('[FCM_WIDGET] Fetching from Firestore: $docPath');
          try {
            final doc = await _firestore.doc(docPath).get();
            if (doc.exists) {
              final itemData = doc.data()!;
              print('[FCM_WIDGET] Raw Firestore data: $itemData');
              print('[FCM_WIDGET] Firestore keys: ${itemData.keys.toList()}');
              
              // Find body field - check all keys that contain "body" (case insensitive)
              String? bodyKey;
              dynamic bodyValue;
              
              for (final key in itemData.keys) {
                if (key.toLowerCase().trim() == 'body') {
                  bodyKey = key;
                  bodyValue = itemData[key];
                  break;
                }
              }
              
              // If not found, try exact match
              if (bodyKey == null) {
                bodyValue = itemData['body'];
              }
              
              print('[FCM_WIDGET] Firestore title: ${itemData['title']}');
              print('[FCM_WIDGET] Firestore body key: ${bodyKey ?? 'body'}');
              print('[FCM_WIDGET] Firestore body value: $bodyValue');
              print('[FCM_WIDGET] Firestore body type: ${bodyValue?.runtimeType}');
              
              widgetData['title'] = itemData['title'] ?? widgetData['title'];
              widgetData['body'] = bodyValue?.toString() ?? widgetData['body'];
              
              print('[FCM_WIDGET] ✅ Firestore data fetched: title=${widgetData['title']}, body=${widgetData['body']}');
            } else {
              print('[FCM_WIDGET] ⚠️ Firestore document does not exist');
            }
          } catch (e) {
            print('[FCM_WIDGET] ❌ Error fetching from Firestore: $e');
            print('[FCM_WIDGET] Stack trace: ${StackTrace.current}');
            // Continue with payload data
          }
        } else {
          print('[FCM_WIDGET] ⚠️ No docPath provided, using payload data');
        }

        print('[FCM_WIDGET] Final widgetData: title=${widgetData['title']}, body=${widgetData['body']}');
        print('[FCM_WIDGET] Calling _updateHomeWidget...');

        // Update home widget
        await _updateHomeWidget(widgetData);
        
        print('[FCM_WIDGET] ✅ _updateHomeWidget completed');
      } else {
        print('[FCM_WIDGET] ❌ Not a DAILY_WIDGET message. Type: $messageType');
        print('[FCM_WIDGET] Available keys in data: ${data.keys.toList()}');
      }
      
      print('[FCM_WIDGET] === MESSAGE HANDLER END ===');
    } catch (e) {
      print('[FCM_WIDGET] ❌ ERROR in _handleMessage: $e');
      print('[FCM_WIDGET] Stack trace: ${StackTrace.current}');
    }
  }

  /// Update home widget with new content
  Future<void> _updateHomeWidget(Map<String, dynamic> data) async {
    try {
      print('[FCM_WIDGET] === UPDATE WIDGET START ===');
      print('[FCM_WIDGET] Data to save: title=${data['title']}, body=${data['body']}, itemId=${data['itemId']}');
      
      print('[FCM_WIDGET] Saving widget_title...');
      final title = data['title'] ?? 'Günün İçeriği';
      await HomeWidget.saveWidgetData<String>(_widgetTitleKey, title);
      print('[FCM_WIDGET] ✅ widget_title saved: $title');
      
      print('[FCM_WIDGET] Saving widget_body...');
      final body = data['body'] ?? '';
      await HomeWidget.saveWidgetData<String>(_widgetBodyKey, body);
      print('[FCM_WIDGET] ✅ widget_body saved: $body');
      
      print('[FCM_WIDGET] Saving widget_itemId...');
      final itemId = data['itemId'] ?? '';
      await HomeWidget.saveWidgetData<String>(_widgetItemIdKey, itemId);
      print('[FCM_WIDGET] ✅ widget_itemId saved: $itemId');
      
      print('[FCM_WIDGET] Saving widget_updatedAt...');
      final updatedAt = data['updatedAt'] ?? DateTime.now().toIso8601String();
      await HomeWidget.saveWidgetData<String>(_widgetUpdatedAtKey, updatedAt);
      print('[FCM_WIDGET] ✅ widget_updatedAt saved: $updatedAt');

      // Verify data was saved by reading it back from SharedPreferences
      print('[FCM_WIDGET] === VERIFYING SAVED DATA ===');
      final savedTitle = await HomeWidget.getWidgetData<String>(_widgetTitleKey, defaultValue: '');
      final savedBody = await HomeWidget.getWidgetData<String>(_widgetBodyKey, defaultValue: '');
      final savedItemId = await HomeWidget.getWidgetData<String>(_widgetItemIdKey, defaultValue: '');
      final savedUpdatedAt = await HomeWidget.getWidgetData<String>(_widgetUpdatedAtKey, defaultValue: '');
      
      print('[FCM_WIDGET] ✅ Verified widget_title in storage: $savedTitle');
      print('[FCM_WIDGET] ✅ Verified widget_body in storage: $savedBody');
      print('[FCM_WIDGET] ✅ Verified widget_itemId in storage: $savedItemId');
      print('[FCM_WIDGET] ✅ Verified widget_updatedAt in storage: $savedUpdatedAt');
      print('[FCM_WIDGET] === VERIFICATION COMPLETE ===');

      print('[FCM_WIDGET] Calling HomeWidget.updateWidget...');
      // Trigger widget update
      // Use qualifiedAndroidName for subpackage (widget.DailyWidgetProvider)
      await HomeWidget.updateWidget(
        name: 'DailyWidget',
        iOSName: 'DailyWidget',
        androidName: 'DailyWidgetProvider',
        qualifiedAndroidName: 'com.siyazilim.periodicallynotification.widget.DailyWidgetProvider',
      );
      print('[FCM_WIDGET] ✅ HomeWidget.updateWidget completed');

      print('[FCM_WIDGET] ✅ Home widget updated successfully');
      print('[FCM_WIDGET] === UPDATE WIDGET END ===');
    } catch (e) {
      print('[FCM_WIDGET] ❌ ERROR updating home widget: $e');
      print('[FCM_WIDGET] Error type: ${e.runtimeType}');
      print('[FCM_WIDGET] Stack trace: ${StackTrace.current}');
    }
  }

  /// Unsubscribe from topic (if needed)
  Future<void> unsubscribe() async {
    await _messaging.unsubscribeFromTopic(_topic);
    print('Unsubscribed from topic: $_topic');
  }
}

/// Top-level background message handler
/// Must be a top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('[FCM_WIDGET] Background message received: ${message.messageId}');
  
  // Handle the message
  final service = FirebaseService();
  await service._handleMessage(message);
}

