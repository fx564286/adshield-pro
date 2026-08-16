import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const ComfortRouteApp());

enum RouteMode { fast, comfort, weather, indoor, supply }

class AppColors {
  static const background = Color(0xFFF8F5F7);
  static const surface = Color(0xFFFFFCFD);
  static const surfaceStrong = Color(0xFFFFFFFF);
  static const primary = Color(0xFFA86F88);
  static const primaryDeep = Color(0xFF7C5064);
  static const primarySoft = Color(0xFFF3E5EB);
  static const text = Color(0xFF2E2930);
  static const textMuted = Color(0xFF756D73);
  static const shadow = Color(0x140F0810);
  static const shade = Color(0xFF4F886A);
  static const indoor = Color(0xFF756FA6);
  static const water = Color(0xFF4D7FA5);
  static const heat = Color(0xFFB67C49);
  static const map = Color(0xFFF0ECEF);
  static const road = Color(0xFFD8D0D5);
  static const building = Color(0xFFE6DEE3);
}

class AppSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
}

class AppRadius {
  static const control = 20.0;
  static const card = 24.0;
  static const sheet = 30.0;
  static const map = 30.0;
  static const pill = 999.0;
}

class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const curve = Curves.easeOutCubic;
}

class AppShadows {
  static const soft = [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}

class RouteData {
  const RouteData({
    required this.name,
    required this.distanceKm,
    required this.minutes,
    required this.indoor,
    required this.shade,
    required this.water,
    required this.toilets,
    required this.buildings,
    required this.heatExposure,
  });

  final String name;
  final double distanceKm;
  final int minutes;
  final int indoor;
  final int shade;
  final int water;
  final int toilets;
  final int buildings;
  final int heatExposure;

  double score(RouteMode mode) {
    switch (mode) {
      case RouteMode.fast:
        return distanceKm * 55 + minutes * 4 - shade * .15 - indoor * .1;
      case RouteMode.comfort:
        return distanceKm * 30 +
            minutes * 2.5 +
            heatExposure * 1.7 -
            shade * .7 -
            indoor * .65 -
            water * 5 -
            toilets * 3;
      case RouteMode.weather:
        return distanceKm * 24 +
            heatExposure * 2.1 -
            shade * .95 -
            indoor * 1.15 -
            buildings * 4;
      case RouteMode.indoor:
        return distanceKm * 27 +
            minutes * 1.8 -
            indoor * 1.45 -
            buildings * 8 -
            shade * .35;
      case RouteMode.supply:
        return distanceKm * 29 +
            minutes * 2 -
            water * 16 -
            toilets * 11 -
            shade * .25 -
            indoor * .2;
    }
  }
}

const sampleRoutes = <RouteData>[
  RouteData(
    name: '빠른 길',
    distanceKm: 2.30,
    minutes: 31,
    indoor: 4,
    shade: 31,
    water: 1,
    toilets: 1,
    buildings: 0,
    heatExposure: 72,
  ),
  RouteData(
    name: '쾌적한 길',
    distanceKm: 2.48,
    minutes: 34,
    indoor: 28,
    shade: 72,
    water: 3,
    toilets: 2,
    buildings: 2,
    heatExposure: 31,
  ),
  RouteData(
    name: '날씨 회피',
    distanceKm: 2.66,
    minutes: 37,
    indoor: 61,
    shade: 84,
    water: 4,
    toilets: 3,
    buildings: 4,
    heatExposure: 18,
  ),
];

class ComfortRouteApp extends StatelessWidget {
  const ComfortRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondaryContainer: AppColors.primarySoft,
      onSecondaryContainer: AppColors.primaryDeep,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '쾌적길',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: AppColors.background,
        fontFamilyFallback: const ['sans-serif'],
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 22,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
          titleMedium: TextStyle(
            fontSize: 15,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: AppColors.text,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppColors.textMuted,
          ),
          labelLarge: TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 66,
          elevation: 0,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primarySoft,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11.5,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? AppColors.primaryDeep
                  : AppColors.textMuted,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 23,
              color: states.contains(WidgetState.selected)
                  ? AppColors.primaryDeep
                  : AppColors.textMuted,
            ),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          modalBackgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.text,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  RouteMode mode = RouteMode.comfort;
  String selectedRoute = '쾌적한 길';
  int bottomIndex = 0;

  List<RouteData> get ranked {
    final copy = sampleRoutes.toList()
      ..sort((a, b) => a.score(mode).compareTo(b.score(mode)));
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final routes = ranked;
    final recommended = routes.first;
    final alternatives = routes.skip(1).toList();
    if (!routes.any((route) => route.name == selectedRoute)) {
      selectedRoute = recommended.name;
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactHeight = constraints.maxHeight < 700;
            final panelHeight = compactHeight ? 240.0 : 270.0;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.md,
                    AppSpace.sm,
                    AppSpace.md,
                    AppSpace.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppSearchBar(onTap: _showDestinationSheet),
                      ),
                      const SizedBox(width: AppSpace.xs),
                      AppCircleButton(
                        icon: Icons.my_location_rounded,
                        onTap: _showLocationNotice,
                      ),
                    ],
                  ),
                ),
                AppModeBar(
                  selected: mode,
                  onChanged: (value) {
                    setState(() {
                      mode = value;
                      final sorted = ranked;
                      selectedRoute = sorted.first.name;
                    });
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.sm,
                      AppSpace.xs,
                      AppSpace.sm,
                      AppSpace.xs,
                    ),
                    child: AppMapCard(
                      mode: mode,
                      selectedRoute: selectedRoute,
                      recommended: recommended,
                      onSummaryTap: () => _showRouteDetails(recommended),
                    ),
                  ),
                ),
                SizedBox(
                  height: panelHeight,
                  child: RoutePanel(
                    recommended: recommended,
                    alternatives: alternatives,
                    selectedRoute: selectedRoute,
                    compact: compactHeight,
                    onSelect: (route) {
                      setState(() => selectedRoute = route.name);
                    },
                    onStart: _showStartSheet,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: bottomIndex,
          onDestinationSelected: (value) {
            setState(() => bottomIndex = value);
            if (value != 0) {
              _showSectionPreview(value);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: '지도',
            ),
            NavigationDestination(
              icon: Icon(Icons.alt_route_outlined),
              selectedIcon: Icon(Icons.alt_route_rounded),
              label: '경로',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_border_rounded),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: '저장',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('v0.3 디자인 샘플에서는 현재 위치를 부천 중심으로 표시합니다.'),
      ),
    );
  }

  void _showSectionPreview(int index) {
    const names = ['지도', '경로', '저장', '설정'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${names[index]} 화면은 다음 내비게이션 단계에서 연결합니다.')),
    );
  }

  void _showDestinationSheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => AppSheetFrame(
        title: '목적지 선택',
        subtitle: 'v0.3은 디자인 통합 검증용 샘플입니다.',
        child: Column(
          children: [
            AppListSurface(
              icon: Icons.flag_rounded,
              title: '부천시청',
              subtitle: '샘플 목적지 · 실제 검색 API 연결 전',
              onTap: () => Navigator.pop(sheetContext),
            ),
            const SizedBox(height: AppSpace.xs),
            AppListSurface(
              icon: Icons.park_rounded,
              title: '상동호수공원',
              subtitle: '샘플 목적지 · 쾌적 경로 비교용',
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  void _showRouteDetails(RouteData route) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => AppSheetFrame(
        title: route.name,
        subtitle:
            '${route.distanceKm.toStringAsFixed(2)} km · ${route.minutes}분 · 건물 통과 ${route.buildings}곳',
        child: Column(
          children: [
            MetricGrid(route: route),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showStartSheet(route);
                },
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('이 경로로 출발'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStartSheet(RouteData route) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => AppSheetFrame(
        title: '${route.name} 선택',
        subtitle:
            '${route.distanceKm.toStringAsFixed(2)} km · ${route.minutes}분 · 그늘 ${route.shade}% · 실내 ${route.indoor}%',
        child: Column(
          children: [
            const AppStatusNotice(
              icon: Icons.info_outline_rounded,
              text: '현재 APK는 디자인 통합 샘플입니다. 실제 GPS 안내는 v0.4부터 연결합니다.',
            ),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${route.name}을(를) 선택했습니다.')),
                  );
                },
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('샘플 경로 선택'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceStrong,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: onTap,
        child: const SizedBox(
          height: 52,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: AppColors.textMuted),
                SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    '어디로 갈까요?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.tune_rounded, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppCircleButton extends StatelessWidget {
  const AppCircleButton({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceStrong,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: AppColors.primaryDeep),
        ),
      ),
    );
  }
}

class AppModeBar extends StatelessWidget {
  const AppModeBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final RouteMode selected;
  final ValueChanged<RouteMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xxs,
        ),
        itemCount: RouteMode.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.xs),
        itemBuilder: (_, index) {
          final mode = RouteMode.values[index];
          return AppModeChip(
            icon: modeIcon(mode),
            label: modeLabel(mode),
            selected: mode == selected,
            onTap: () => onChanged(mode),
          );
        },
      ),
    );
  }
}

class AppModeChip extends StatelessWidget {
  const AppModeChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: AppSpace.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? AppColors.primaryDeep : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpace.xxs),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.primaryDeep : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppMapCard extends StatelessWidget {
  const AppMapCard({
    super.key,
    required this.mode,
    required this.selectedRoute,
    required this.recommended,
    required this.onSummaryTap,
  });
  final RouteMode mode;
  final String selectedRoute;
  final RouteData recommended;
  final VoidCallback onSummaryTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.map),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: ComfortMapPainter(
              selectedRoute: selectedRoute,
              mode: mode,
            ),
          ),
          const Positioned(
            left: AppSpace.sm,
            top: AppSpace.sm,
            child: AppMapBadge(
              icon: Icons.thermostat_rounded,
              label: '31°C · 더움',
              semanticColor: AppColors.heat,
            ),
          ),
          const Positioned(
            right: AppSpace.sm,
            top: AppSpace.sm,
            child: AppMapBadge(
              icon: Icons.science_outlined,
              label: '샘플',
              semanticColor: AppColors.primary,
            ),
          ),
          Positioned(
            left: AppSpace.sm,
            right: AppSpace.sm,
            bottom: AppSpace.sm,
            child: AppMapSummaryCard(
              mode: mode,
              route: recommended,
              onTap: onSummaryTap,
            ),
          ),
        ],
      ),
    );
  }
}

class AppMapBadge extends StatelessWidget {
  const AppMapBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticColor,
  });
  final IconData icon;
  final String label;
  final Color semanticColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: semanticColor),
          const SizedBox(width: AppSpace.xxs),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class AppMapSummaryCard extends StatelessWidget {
  const AppMapSummaryCard({
    super.key,
    required this.mode,
    required this.route,
    required this.onTap,
  });
  final RouteMode mode;
  final RouteData route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  modeIcon(mode),
                  color: AppColors.primaryDeep,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${modeLabel(mode)} 추천',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${route.name} · 그늘 ${route.shade}% · 실내 ${route.indoor}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class RoutePanel extends StatelessWidget {
  const RoutePanel({
    super.key,
    required this.recommended,
    required this.alternatives,
    required this.selectedRoute,
    required this.compact,
    required this.onSelect,
    required this.onStart,
  });
  final RouteData recommended;
  final List<RouteData> alternatives;
  final String selectedRoute;
  final bool compact;
  final ValueChanged<RouteData> onSelect;
  final ValueChanged<RouteData> onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpace.md,
        compact ? AppSpace.sm : AppSpace.md,
        AppSpace.md,
        AppSpace.sm,
      ),
      child: Column(
        children: [
          PrimaryRouteCard(
            route: recommended,
            selected: selectedRoute == recommended.name,
            compact: compact,
            onTap: () => onSelect(recommended),
            onStart: () => onStart(recommended),
          ),
          SizedBox(height: compact ? AppSpace.xs : AppSpace.sm),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < alternatives.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: CompactRouteCard(
                      route: alternatives[i],
                      selected: selectedRoute == alternatives[i].name,
                      onTap: () => onSelect(alternatives[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryRouteCard extends StatelessWidget {
  const PrimaryRouteCard({
    super.key,
    required this.route,
    required this.selected,
    required this.compact,
    required this.onTap,
    required this.onStart,
  });
  final RouteData route;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.standard,
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySoft : AppColors.surfaceStrong,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: EdgeInsets.all(compact ? AppSpace.sm : AppSpace.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              route.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(width: AppSpace.xs),
                          const AppRecommendationBadge(),
                        ],
                      ),
                      const SizedBox(height: AppSpace.xxs),
                      Text(
                        '${route.distanceKm.toStringAsFixed(2)} km · ${route.minutes}분',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: AppSpace.xs),
                        Wrap(
                          spacing: AppSpace.xs,
                          runSpacing: AppSpace.xxs,
                          children: [
                            AppMetricPill(
                              icon: Icons.park_rounded,
                              label: '그늘 ${route.shade}%',
                              color: AppColors.shade,
                            ),
                            AppMetricPill(
                              icon: Icons.apartment_rounded,
                              label: '실내 ${route.indoor}%',
                              color: AppColors.indoor,
                            ),
                            AppMetricPill(
                              icon: Icons.water_drop_rounded,
                              label: '물 ${route.water}',
                              color: AppColors.water,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                FilledButton(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    minimumSize: Size(compact ? 62 : 72, 44),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                  ),
                  child: const Text('출발'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CompactRouteCard extends StatelessWidget {
  const CompactRouteCard({
    super.key,
    required this.route,
    required this.selected,
    required this.onTap,
  });
  final RouteData route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.standard,
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySoft : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: AppSpace.xs,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  '${route.distanceKm.toStringAsFixed(2)} km · ${route.minutes}분',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '그늘 ${route.shade}% · 실내 ${route.indoor}%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppRecommendationBadge extends StatelessWidget {
  const AppRecommendationBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Text(
        '추천',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class AppMetricPill extends StatelessWidget {
  const AppMetricPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpace.xxs),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class AppSheetFrame extends StatelessWidget {
  const AppSheetFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.xxs,
        AppSpace.lg,
        AppSpace.xl + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpace.xxs),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpace.lg),
          child,
        ],
      ),
    );
  }
}

class AppListSurface extends StatelessWidget {
  const AppListSurface({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primaryDeep),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class AppStatusNotice extends StatelessWidget {
  const AppStatusNotice({
    super.key,
    required this.icon,
    required this.text,
  });
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryDeep),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.primaryDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.route});
  final RouteData route;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.park_rounded, '그늘', '${route.shade}%', AppColors.shade),
      (Icons.apartment_rounded, '실내', '${route.indoor}%', AppColors.indoor),
      (Icons.water_drop_rounded, '음수', '${route.water}곳', AppColors.water),
      (Icons.wc_rounded, '화장실', '${route.toilets}곳', AppColors.primary),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - AppSpace.xs) / 2;
        return Wrap(
          spacing: AppSpace.xs,
          runSpacing: AppSpace.xs,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth,
              child: Container(
                padding: const EdgeInsets.all(AppSpace.sm),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Row(
                  children: [
                    Icon(item.$1, color: item.$4, size: 19),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$2, style: Theme.of(context).textTheme.bodySmall),
                          Text(
                            item.$3,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class ComfortMapPainter extends CustomPainter {
  ComfortMapPainter({required this.selectedRoute, required this.mode});
  final String selectedRoute;
  final RouteMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.map);

    final buildingPaint = Paint()..color = AppColors.building;
    final seed = math.Random(9);
    for (var i = 0; i < 14; i++) {
      final w = 34 + seed.nextDouble() * 52;
      final h = 24 + seed.nextDouble() * 48;
      final x = seed.nextDouble() * math.max(1, size.width - w);
      final y = seed.nextDouble() * math.max(1, size.height - h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          const Radius.circular(8),
        ),
        buildingPaint,
      );
    }

    final road = Paint()
      ..color = AppColors.road
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final thinRoad = Paint()
      ..color = AppColors.surfaceStrong.withValues(alpha: .75)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (final y in [size.height * .22, size.height * .48, size.height * .74]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), road);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), thinRoad);
    }
    for (final x in [size.width * .20, size.width * .53, size.width * .82]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), road);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), thinRoad);
    }

    final routeColor = switch (mode) {
      RouteMode.fast => AppColors.primary,
      RouteMode.comfort => AppColors.shade,
      RouteMode.weather => AppColors.heat,
      RouteMode.indoor => AppColors.indoor,
      RouteMode.supply => AppColors.water,
    };

    final routePaint = Paint()
      ..color = routeColor
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * .12, size.height * .82)
      ..lineTo(size.width * .20, size.height * .74)
      ..lineTo(size.width * .20, size.height * .48)
      ..lineTo(size.width * .53, size.height * .48)
      ..lineTo(size.width * .53, size.height * .22)
      ..lineTo(size.width * .84, size.height * .22);
    canvas.drawPath(path, routePaint);

    if (selectedRoute == '날씨 회피') {
      canvas.drawLine(
        Offset(size.width * .53, size.height * .48),
        Offset(size.width * .53, size.height * .22),
        Paint()
          ..color = AppColors.indoor
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(
      Offset(size.width * .12, size.height * .82),
      8,
      Paint()..color = AppColors.primaryDeep,
    );
    canvas.drawCircle(
      Offset(size.width * .84, size.height * .22),
      9,
      Paint()..color = routeColor,
    );
  }

  @override
  bool shouldRepaint(covariant ComfortMapPainter oldDelegate) {
    return oldDelegate.selectedRoute != selectedRoute || oldDelegate.mode != mode;
  }
}

String modeLabel(RouteMode mode) {
  switch (mode) {
    case RouteMode.fast:
      return '빠른';
    case RouteMode.comfort:
      return '쾌적';
    case RouteMode.weather:
      return '날씨';
    case RouteMode.indoor:
      return '실내';
    case RouteMode.supply:
      return '보급';
  }
}

IconData modeIcon(RouteMode mode) {
  switch (mode) {
    case RouteMode.fast:
      return Icons.bolt_rounded;
    case RouteMode.comfort:
      return Icons.eco_rounded;
    case RouteMode.weather:
      return Icons.cloud_outlined;
    case RouteMode.indoor:
      return Icons.apartment_rounded;
    case RouteMode.supply:
      return Icons.water_drop_rounded;
  }
}
