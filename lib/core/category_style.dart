import 'package:flutter/material.dart';

/// Colours a category can use (ARGB ints so they can be stored in SQLite).
const List<int> kCategoryColors = [
  0xFF3F51B5, 0xFF2196F3, 0xFF009688, 0xFF4CAF50, 0xFFFF9800,
  0xFFF44336, 0xFF9C27B0, 0xFFE91E63, 0xFF795548, 0xFF607D8B,
];

/// Icons a category can use, keyed by the string stored in the database.
const Map<String, IconData> kCategoryIcons = {
  'folder': Icons.folder,
  'badge': Icons.badge,
  'gavel': Icons.gavel,
  'receipt': Icons.receipt_long,
  'assignment': Icons.assignment,
  'work': Icons.work,
  'school': Icons.school,
  'person': Icons.person,
  'home': Icons.home,
  'bank': Icons.account_balance,
  'payments': Icons.payments,
  'medical': Icons.medical_services,
  'flight': Icons.flight,
  'inventory': Icons.inventory_2,
  'description': Icons.description,
};

IconData iconForCategory(String key) => kCategoryIcons[key] ?? Icons.folder;
