import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/motivation.dart';

class MotivationService {
  static const String assetPath = 'assets/data/motivition.json';

  static Future<List<Motivation>> loadAll() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      if (raw.trim().isEmpty) return [];
      final decoded = json.decode(raw);
      if (decoded is List) {
        // Map JSON objects that use firebase-like keys (title, body, sentAt, order, image)
        return decoded.map((e) => Motivation.fromMap(Map<String, dynamic>.from(e))).toList();
      }
      return [];
    } catch (e) {
      // If asset missing or invalid, return empty
      return [];
    }
  }

  static Motivation? latest(List<Motivation> list) {
    if (list.isEmpty) return null;
    // assume list is in chronological order or use updatedAt
    return list.last;
  }
}
