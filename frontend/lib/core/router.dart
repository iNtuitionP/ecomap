/// 앱 라우터 — go_router + 하단 네비 4탭 셸.
///
/// 탭: 홈(/) · 스캔(/scan) · 지도(/map) · 공백분석(/admin).
/// 보조 라우트(/select, /result, /guide, /gap)는 흐름상 가까운 탭 브랜치에
/// 속해 하단 네비가 유지된다 (목업 정본: 모든 화면에 네비 노출).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_screen.dart';
import '../features/guide/guide_screen.dart';
import '../features/home/home_screen.dart';
import '../features/map/gap_screen.dart';
import '../features/map/map_screen.dart';
import '../features/scan/manual_select_screen.dart';
import '../features/scan/result_screen.dart';
import '../features/scan/scan_screen.dart';
import 'theme/app_theme.dart';

/// 앱 라우터 생성. 앱 인스턴스마다 새로 만들어 상태 공유를 피한다(테스트 격리).
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // 탭 1 — 홈
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // 탭 2 — 스캔 (촬영 → 인식 결과 → 가이드 / 직접 선택)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scan',
                builder: (context, state) => const ScanScreen(),
              ),
              GoRoute(
                path: '/select',
                builder: (context, state) => ManualSelectScreen(
                  confidence:
                      double.tryParse(state.uri.queryParameters['conf'] ?? ''),
                ),
              ),
              GoRoute(
                path: '/result/:categoryId',
                builder: (context, state) {
                  final manual = state.uri.queryParameters['manual'];
                  return ResultScreen(
                    categoryId: state.pathParameters['categoryId']!,
                    confidence: double.tryParse(
                        state.uri.queryParameters['conf'] ?? ''),
                    manual: manual == '1' || manual == 'true',
                  );
                },
              ),
              GoRoute(
                path: '/guide/:categoryId',
                builder: (context, state) => GuideScreen(
                  categoryId: state.pathParameters['categoryId']!,
                ),
              ),
            ],
          ),
          // 탭 3 — 지도 (전체 / 품목 필터 / 공백 안내)
          // ?lat=&lng= : 공백 화면 "위치 보기" 포커스 좌표 (T6).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => MapScreen(
                  focusLat:
                      double.tryParse(state.uri.queryParameters['lat'] ?? ''),
                  focusLng:
                      double.tryParse(state.uri.queryParameters['lng'] ?? ''),
                ),
                routes: [
                  GoRoute(
                    path: ':categoryId',
                    builder: (context, state) => MapScreen(
                      categoryId: state.pathParameters['categoryId'],
                      focusLat: double.tryParse(
                          state.uri.queryParameters['lat'] ?? ''),
                      focusLng: double.tryParse(
                          state.uri.queryParameters['lng'] ?? ''),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/gap/:categoryId',
                builder: (context, state) => GapScreen(
                  categoryId: state.pathParameters['categoryId']!,
                ),
              ),
            ],
          ),
          // 탭 4 — 공백분석 (어드민)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                builder: (context, state) => const AdminScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// 하단 네비 4탭 셸 — 아이콘 + 한글 라벨, 활성 그린 (목업 네비 스타일).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.photo_camera_outlined),
              activeIcon: Icon(Icons.photo_camera_rounded),
              label: '스캔',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map_rounded),
              label: '지도',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined),
              activeIcon: Icon(Icons.insights_rounded),
              label: '공백분석',
            ),
          ],
        ),
      ),
    );
  }
}
