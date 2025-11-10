import 'package:flutter/material.dart';

ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  primaryColor: Color(0xFF00FF41),
  scaffoldBackgroundColor: Color(0xFF000000),
  primaryColorDark: Color(0xFF0D0D0D),
  cardColor: Color(0xFF0D0D0D),
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF1A1A1A),
    elevation: 1,
    centerTitle: false,
    iconTheme: IconThemeData(color: Color(0xFF00FF41)),
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Color(0xFF00FF41),
      fontFamily: 'StackSans',
    ),
  ),
  textTheme: TextTheme(
    displayLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Color(0xFF00FF41),
      fontFamily: 'StackSans',
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: Color(0xFF22FF22),
      fontFamily: 'StackSansText',
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFF0D0D0D),
      foregroundColor: Color(0xFF00FF41),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Color(0xFF00FF41),
      side: BorderSide(color: Color(0xFF00FF41)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Color(0xFF00FF41),
    ),
  ),
);
