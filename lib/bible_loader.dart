import 'dart:convert';
import 'package:flutter/services.dart';

class BibleLoader {
  static Future<Map<String, dynamic>> loadJson(String path) async {
    final jsonString = await rootBundle.loadString(path);
    return json.decode(jsonString) as Map<String, dynamic>;
  }
}
