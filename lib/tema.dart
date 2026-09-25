import 'package:flutter/material.dart';

class Cores {
  static const fundo = Color(0xFF0B0B11);
  static const card = Color(0xFF15151E);
  static const card2 = Color(0xFF1D1D29);
  static const borda = Color(0xFF2A2A3A);
  static const texto = Color(0xFFF2F2F7);
  static const texto2 = Color(0xFF9B9BB2);
  static const texto3 = Color(0xFF6B6B80);

  static const verde = Color(0xFF34D399);
  static const vermelho = Color(0xFFF87171);
  static const azul = Color(0xFF60A5FA);
  static const roxo = Color(0xFFA78BFA);
  static const roxoForte = Color(0xFF7C3AED);
  static const ciano = Color(0xFF22D3EE);
  static const amarelo = Color(0xFFFBBF24);
  static const laranja = Color(0xFFFB923C);
}

ThemeData criarTema() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Cores.roxoForte,
      brightness: Brightness.dark,
      primary: Cores.roxo,
      surface: Cores.card,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: Cores.fundo,
    appBarTheme: const AppBarTheme(
      backgroundColor: Cores.fundo,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: Cores.texto),
    ),
    cardTheme: CardTheme(
      color: Cores.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Cores.card2,
      labelStyle: const TextStyle(color: Cores.texto2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Cores.roxo, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Cores.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: Cores.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Cores.card2,
      contentTextStyle: const TextStyle(color: Cores.texto),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerColor: Cores.borda,
  );
}
