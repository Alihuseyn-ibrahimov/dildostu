import 'package:flutter/material.dart';

/// Paket id-sinə görə kateqoriya ikonu (ana səhifə kartları üçün). Naməlum
/// id → Icons.translate (fallback).
const _icons = <String, IconData>{
  'airport': Icons.flight,
  'cafe': Icons.local_cafe,
  'evening': Icons.nightlight_round,
  'greetings': Icons.waving_hand,
  'hotel': Icons.hotel,
  'market': Icons.shopping_cart,
  'morning': Icons.wb_sunny,
  'pharmacy': Icons.local_pharmacy,
  'restaurant': Icons.restaurant,
  'transport': Icons.directions_bus,
};

IconData packIcon(String packId) => _icons[packId] ?? Icons.translate;
