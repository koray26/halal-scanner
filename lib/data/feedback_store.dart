/// Nutzerhinweise zu Produkten und Zutaten – nur lokal gespeichert.
///
/// Sicherheitsregeln:
///  * Jeder Hinweis ist UNBESTÄTIGT.
///  * Hinweise fließen NICHT in die Bewertung ein (die Regel-Engine kennt
///    diese Klasse nicht).
///  * Weitergabe nur freiwillig durch den Nutzer (Kopieren / E-Mail).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum FeedbackKind {
  ingredientInfo,
  manufacturerSource,
  correctIngredients,
  outdated,
  wrongInfo,
}

class FeedbackEntry {
  FeedbackEntry({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.text,
    this.barcode,
    this.productName,
    this.ingredient,
    this.sourceUrl,
  });

  final String id;
  final DateTime createdAt;
  final FeedbackKind kind;
  final String text;
  final String? barcode;
  final String? productName;
  final String? ingredient;
  final String? sourceUrl;

  /// Immer unbestätigt – es gibt in der App keinen Weg, das zu ändern.
  String get status => 'unconfirmed';

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'kind': kind.name,
        'text': text,
        'barcode': barcode,
        'productName': productName,
        'ingredient': ingredient,
        'sourceUrl': sourceUrl,
        'status': status,
      };

  factory FeedbackEntry.fromJson(Map<String, dynamic> j) => FeedbackEntry(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        kind: FeedbackKind.values.byName(j['kind'] as String),
        text: j['text'] as String,
        barcode: j['barcode'] as String?,
        productName: j['productName'] as String?,
        ingredient: j['ingredient'] as String?,
        sourceUrl: j['sourceUrl'] as String?,
      );
}

class FeedbackStore {
  static const _key = 'user_feedback_v1';

  Future<List<FeedbackEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => FeedbackEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<FeedbackEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  /// Export als JSON (zum Kopieren oder Versenden durch den Nutzer).
  static String exportJson(List<FeedbackEntry> entries) =>
      const JsonEncoder.withIndent('  ').convert({
        'app': 'HalalScanner',
        'format': 'feedback-v1',
        'note': 'Unbestätigte Nutzerhinweise / unconfirmed user reports',
        'entries': entries.map((e) => e.toJson()).toList(),
      });
}
