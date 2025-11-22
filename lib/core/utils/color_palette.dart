import 'package:flutter/material.dart';

class ColorPalette {
  static const List<Color> all = [
    Color(0xFFFF6B6B), // Coral Red
    Color(0xFFFF9F43), // Orange
    Color(0xFFFECA57), // Sunflower Yellow
    Color(0xFF1DD1A1), // Mint Green
    Color(0xFF48DBFB), // Cyan
    Color(0xFF54A0FF), // Sky Blue
    Color(0xFF5F27CD), // Purple
    Color(0xFF9B59B6), // Amethyst
    Color(0xFFFF9FF3), // Pink
    Color(0xFF00D2D3), // Teal
    Color(0xFF2E86DE), // Strong Blue
    Color(0xFF8395A7), // Grey Blue
  ];

  static Color getRandom() {
    return all[DateTime.now().millisecondsSinceEpoch % all.length];
  }
}
