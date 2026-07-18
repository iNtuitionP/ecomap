import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 섹션 제목 (17 / w600) — 우측 [trailing] 위젯 선택.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.text, this.trailing});

  final String text;

  /// 제목 우측 끝 위젯 (예: '전체 보기' 텍스트 버튼).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: AppTextStyles.section)),
        ?trailing,
      ],
    );
  }
}
