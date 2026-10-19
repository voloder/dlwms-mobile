import 'package:dlwms_mobile/app.dart';
import 'package:dlwms_mobile/services/background_service.dart';
import 'package:dlwms_mobile/services/local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lets the background service tell the UI when new announcements arrive.
  await BackgroundService.initialize();
  await LocalNotifications.init();

  final prefs = await SharedPreferences.getInstance();

  runApp(buildApp(prefs));
}
