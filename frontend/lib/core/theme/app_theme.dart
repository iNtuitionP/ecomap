/// 에코지도 찌릿 디자인 시스템 — 색·라운드·간격·타이포 토큰 + Material3 테마.
///
/// 모든 화면은 이 파일의 토큰만 사용한다. 색 하드코딩 금지.
/// 목업 정본: designs/demo-flow.png · rest-screens.png · new-screens.png
library;

import 'package:flutter/material.dart';

/// 브랜드 컬러 토큰.
abstract final class AppColors {
  /// 화면 배경 — 세이지 그린.
  static const Color bgSage = Color(0xFFECF3EC);

  /// 카드 배경.
  static const Color card = Color(0xFFFFFFFF);

  /// Primary — 포레스트 그린 (CTA·활성 탭·브랜드).
  static const Color primary = Color(0xFF2E7D46);

  /// Primary Dark — 히어로 그라데이션·눌림 상태.
  static const Color primaryDark = Color(0xFF245C36);

  /// Accent — 라이트 그린 (히어로 위 보조 텍스트·아이콘 배경).
  static const Color accent = Color(0xFF8FD9A8);

  /// 스캔 화면 전용 다크 그린 배경.
  static const Color scanDark = Color(0xFF1B2E22);

  /// 본문 텍스트.
  static const Color textBody = Color(0xFF1C2B21);

  /// 보조 텍스트.
  static const Color textMuted = Color(0xFF5F6F64);

  /// 구분선.
  static const Color divider = Color(0xFFE3EBE3);

  /// 심각도 — 우선순위 1 (빨강).
  static const Color severityRed = Color(0xFFE5484D);

  /// 심각도 — 우선순위 2 (주황). 저신뢰 인식 칩에도 사용.
  static const Color severityOrange = Color(0xFFF79009);

  /// 심각도 — 우선순위 3 (노랑).
  static const Color severityYellow = Color(0xFFEAC54F);
}

/// 라운드 토큰.
abstract final class AppRadius {
  /// 카드 라운드.
  static const double card = 20;

  /// 버튼 라운드.
  static const double button = 14;

  /// 칩(pill) 라운드.
  static const double pill = 999;
}

/// 간격 토큰 (4pt 그리드).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// 화면 좌우 기본 패딩.
  static const double screenEdge = 20;

  /// 풀폭 CTA 높이.
  static const double ctaHeight = 54;
}

/// 타이포 토큰 — Pretendard 번들 폰트.
abstract final class AppTextStyles {
  static const String fontFamily = 'Pretendard';

  /// 화면 제목 22 / w700.
  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textBody,
    height: 1.3,
  );

  /// 섹션 제목 17 / w600.
  static const TextStyle section = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textBody,
    height: 1.35,
  );

  /// 본문 15 / w400.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textBody,
    height: 1.45,
  );

  /// 캡션 13 / w400 · 보조색.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.4,
  );

  /// 버튼 라벨 16 / w600.
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
}

/// 앱 전역 Material3 테마.
ThemeData buildAppTheme() {
  final ColorScheme scheme =
      ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: AppColors.primaryDark,
    surface: AppColors.card,
    onSurface: AppColors.textBody,
    onSurfaceVariant: AppColors.textMuted,
    outlineVariant: AppColors.divider,
    error: AppColors.severityRed,
  );

  final ThemeData base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: AppTextStyles.fontFamily,
    scaffoldBackgroundColor: AppColors.bgSage,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: AppColors.textBody,
          displayColor: AppColors.textBody,
          fontFamily: AppTextStyles.fontFamily,
        )
        .copyWith(
          titleLarge: AppTextStyles.title,
          titleMedium: AppTextStyles.section,
          bodyMedium: AppTextStyles.body,
          bodySmall: AppTextStyles.caption,
          labelLarge: AppTextStyles.button,
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bgSage,
      foregroundColor: AppColors.textBody,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.title.copyWith(fontSize: 20),
      iconTheme: const IconThemeData(color: AppColors.textBody, size: 24),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(AppSpacing.ctaHeight),
        textStyle: AppTextStyles.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(AppSpacing.ctaHeight),
        textStyle: AppTextStyles.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(AppSpacing.ctaHeight),
        textStyle: AppTextStyles.button,
        side: const BorderSide(color: AppColors.primary, width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: AppTextStyles.button.copyWith(fontSize: 15),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.card,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(
        fontFamily: AppTextStyles.fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.6,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: AppTextStyles.fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textBody,
      contentTextStyle: AppTextStyles.body.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
    ),
  );
}
