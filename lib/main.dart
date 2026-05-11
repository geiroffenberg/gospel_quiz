import 'dart:async';

import 'package:flutter/material.dart';
//import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'notification_service.dart';
import 'quiz_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Start notification initialization but don't await it to avoid blocking startup.
  NotificationService.instance.initialize();
  //unawaited(MobileAds.instance.initialize());
  runApp(const QuizApp());
}
