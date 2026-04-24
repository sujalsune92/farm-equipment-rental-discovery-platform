import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary      = Color(0xFF2E7D32);
  static const Color primaryDark  = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color accent       = Color(0xFFF9A825);
  static const Color soil         = Color(0xFF5D4037);
  static const Color cream        = Color(0xFFFFF8E1);
  static const Color background   = Color(0xFFF1F8E9);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary  = Color(0xFF212121);
  static const Color textSecondary= Color(0xFF757575);
  static const Color textHint     = Color(0xFFBDBDBD);
  static const Color error        = Color(0xFFD32F2F);
  static const Color success      = Color(0xFF388E3C);
  static const Color warning      = Color(0xFFF57C00);
  static const Color pending      = Color(0xFF1976D2);
  static const Color divider      = Color(0xFFE0E0E0);
  static const Color shadow       = Color(0x1A000000);
  static const Color stone        = Color(0xFF7F8C8D);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.nunitoTextTheme().copyWith(
        displayMedium: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineLarge: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineMedium: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineSmall: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleLarge: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleMedium: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        bodyMedium: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.nunito(color: AppColors.textHint, fontSize: 14),
        labelStyle: GoogleFonts.nunito(color: AppColors.textSecondary),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppColors.cardBackground,
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.background,
        selectedColor: AppColors.primary,
        labelStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
    );
  }
}

class AppConstants {
  static const String supabaseUrl = 'https://uunemdrgthcwmqxshzug.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_lvrYv8cu5KFvOrYe90k8ZA_yWwEEAFe';

  // Must match the Supabase storage bucket name shown in the dashboard
  static const String equipmentBucket = 'listings';
  static const String profileBucket   = 'profile-images';

  static const String appName    = 'KisanYantra';
  static const String appTagline = 'Farm Equipment at Your Fingertips';
  static const String roleUser   = 'user';       // unified renter/owner
  static const String roleFarmer = 'farmer';     // legacy value
  static const String roleOwner  = 'owner';      // legacy value
  static const String roleAdmin  = 'admin';

  static const String statusPending   = 'Pending';
  static const String statusApproved  = 'Approved';
  static const String statusDeclined  = 'Declined';
  static const String statusInUse     = 'In Use';
  static const String statusCompleted = 'Completed';

  static const List<String> equipmentTypes = [
    'Tractor','Harvester','Tiller','Sprayer',
    'Seeder','Plough','Cultivator','Thresher','Pump','Other',
  ];
  static const int maxImages = 5;
}
