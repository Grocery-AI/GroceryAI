import 'package:flutter/material.dart';

// Dark mode colors
const Color kDarkBg = Color(0xFF064E3B);
const Color kDarkAppBar = Color(0xFF0A3028);
const Color kDarkCard = Color(0xFF0D3D2E);
const Color kDarkText = Color(0xFFF3F4F6);
const Color kDarkTextSecondary = Color(0xFFE8EFEB);

ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  primaryColor: kDarkText,
  scaffoldBackgroundColor: kDarkBg,
  primaryColorDark: kDarkCard,
  cardColor: kDarkCard,
  appBarTheme: AppBarTheme(
    backgroundColor: kDarkAppBar,
    elevation: 1,
    centerTitle: false,
    iconTheme: IconThemeData(color: kDarkText),
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: kDarkText,
      fontFamily: 'StackSans',
    ),
  ),
  textTheme: TextTheme(
    displayLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: kDarkText,
      fontFamily: 'StackSans',
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: kDarkTextSecondary,
      fontFamily: 'StackSansText',
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kDarkCard,
      foregroundColor: kDarkText,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kDarkText,
      side: BorderSide(color: kDarkText),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: kDarkText,
    ),
  ),
);
