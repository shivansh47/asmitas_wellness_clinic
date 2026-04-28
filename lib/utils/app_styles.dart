import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme{
  static const Color primary = Color(0xFF00B0A0);
  static const Color primaryDark = Color(0xFF006A60);
  static const Color darkAzure = Color(0xFF014750);
  static const Color warmSand = Color(0xFFFFF8F2);
  static const Color surfaceContainer = Color(0xFFFAECD9);
  static const Color surfaceContainerLowest = Color(0xFFEDE0CD);
  static const Color onSurface = Color(0xFF211B0F);
  static const Color dustyRose = Color(0xFFD9A5B3);

  static TextStyle heading = GoogleFonts.quicksand(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppTheme.primary,
  );
}