import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'quiz_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  runApp(const QuizApp());
}
