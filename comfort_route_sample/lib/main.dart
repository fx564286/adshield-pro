import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const ComfortRouteSampleApp());

enum RouteMode { fast, comfort, weather, indoor, supply }

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
        return distanceKm * 30 + minutes * 2.5 + heatExposure * 1.7 - shade * .7 - indoor * .65 - water * 5 - toilets * 3;
      case RouteMode.weather:
        return distanceKm * 24 + heatExposure * 2.1 - shade * .95 - indoor * 1.15 - buildings * 4;
      case RouteMode.indoor:
        return distanceKm * 27 + minutes * 1.8 - indoor * 1.45 - buildings * 8 - shade * .35;
      case RouteMode.supply:
        return distanceKm * 29 + minutes * 2 - water * 16 - toilets * 11 - shade * .25 - indoor * .2;
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

class ComfortRouteSampleApp extends StatelessWidget {
  const ComfortRouteSampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFB8849C);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: const Color(0xFFFFFBFD),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '쾌적길',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF8F5F7),
        fontFamilyFallback: const ['sans-serif'],
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
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
    final copy = sampleRoutes.toList();
    copy.sort((a, b) => a.score(mode).compareTo(b.score(mode)));
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final routes = ranked;
    if (!routes.any((e) => e.name == selectedRoute)) {
      selectedRoute = routes.first.name;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      readOnly: true,
                      onTap: _showDestinationSheet,
                      decoration: const InputDecoration(
                        hintText: '어디로 갈까요?',
                        prefixIcon: Icon(Icons.search_rounded),
                        suffixIcon: Icon(Icons.tune_rounded),
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _roundButton(Icons.my_location_rounded, () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('샘플에서는 현재 위치를 부천 중심으로 표시합니다.')),
                    );
                  }),
                ],
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: RouteMode.values.map((item) {
                  final selected = item == mode;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      selected: selected,
                      showCheckmark: false,
                      side: BorderSide.none,
                      avatar: Icon(_modeIcon(item), size: 17),
                      label: Text(_modeLabel(item)),
                      onSelected: (_) => setState(() {
                        mode = item;
                        selectedRoute = ranked.first.name;
                      }),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: ComfortMapPainter(
                          selectedRoute: selectedRoute,
                          mode: mode,
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _glassPill(
                          icon: Icons.thermostat_rounded,
                          text: '샘플 31°C · 체감 더움',
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: _glassPill(
                          icon: Icons.science_outlined,
                          text: '샘플 데이터',
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        right: 12,
                        child: _mapSummary(routes.first),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 185,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                scrollDirection: Axis.horizontal,
                itemCount: routes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final route = routes[index];
                  return _routeCard(route, index == 0);
                },
              ),
            ),
            NavigationBar(
              selectedIndex: bottomIndex,
              height: 66,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (value) => setState(() => bottomIndex = value),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.map_rounded), label: '지도'),
                NavigationDestination(icon: Icon(Icons.alt_route_rounded), label: '경로'),
                NavigationDestination(icon: Icon(Icons.bookmark_outline_rounded), label: '저장'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), label: '설정'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeCard(RouteData route, bool recommended) {
    final active = selectedRoute == route.name;
    return GestureDetector(
      onTap: () => setState(() => selectedRoute = route.name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 272,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFF7FB) : Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    route.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                if (recommended)
                  const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFFAD718B)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${route.distanceKm.toStringAsFixed(2)} km · ${route.minutes}분',
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _metric('실내 ${route.indoor}%'),
                _metric('그늘 ${route.shade}%'),
                _metric('물 ${route.water}'),
                _metric('화장실 ${route.toilets}'),
                _metric('건물 ${route.buildings}'),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    active ? '지도에 표시 중' : '눌러서 비교',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    setState(() => selectedRoute = route.name);
                    _showStartSheet(route);
                  },
                  icon: const Icon(Icons.navigation_rounded, size: 17),
                  label: const Text('선택'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapSummary(RouteData route) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .91),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFF0E1E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_rounded, color: Color(0xFF956B7D)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_modeLabel(mode)} 추천', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  '${route.name} · 그늘 ${route.shade}% · 실내 ${route.indoor}%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

  Widget _metric(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF4EFF2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
      );

  Widget _roundButton(IconData icon, VoidCallback onTap) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 52, height: 52, child: Icon(icon)),
        ),
      );

  Widget _glassPill({required IconData icon, required String text}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  void _showDestinationSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('목적지 샘플', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.flag_rounded)),
              title: const Text('부천시청'),
              subtitle: const Text('실제 검색 API 연결 전 샘플 목적지'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              tileColor: const Color(0xFFF7F2F5),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showStartSheet(RouteData route) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.navigation_rounded, size: 42, color: Color(0xFF9E7185)),
            const SizedBox(height: 8),
            Text('${route.name} 선택', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${route.distanceKm.toStringAsFixed(2)} km · ${route.minutes}분 · 건물 통과 ${route.buildings}곳'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('샘플 내비게이션: 실제 GPS/음성 엔진은 다음 단계에서 연결합니다.')),
                  );
                },
                child: const Text('샘플 안내 시작'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _modeLabel(RouteMode value) => switch (value) {
        RouteMode.fast => '빠른 길',
        RouteMode.comfort => '쾌적',
        RouteMode.weather => '날씨 회피',
        RouteMode.indoor => '실내 우선',
        RouteMode.supply => '보급 우선',
      };

  IconData _modeIcon(RouteMode value) => switch (value) {
        RouteMode.fast => Icons.bolt_rounded,
        RouteMode.comfort => Icons.eco_rounded,
        RouteMode.weather => Icons.umbrella_rounded,
        RouteMode.indoor => Icons.apartment_rounded,
        RouteMode.supply => Icons.water_drop_rounded,
      };
}

class ComfortMapPainter extends CustomPainter {
  ComfortMapPainter({required this.selectedRoute, required this.mode});

  final String selectedRoute;
  final RouteMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFEAF0EC);
    canvas.drawRect(Offset.zero & size, background);

    final blockPaint = Paint()..color = const Color(0xFFF9F6F4);
    final shadePaint = Paint()..color = const Color(0xFFCFE0D5).withValues(alpha: .82);
    final indoorPaint = Paint()..color = const Color(0xFFE8DCE4).withValues(alpha: .92);
    final road = Paint()
      ..color = Colors.white.withValues(alpha: .95)
      ..strokeWidth = math.max(8, size.width * .024)
      ..strokeCap = StrokeCap.round;

    final minorRoad = Paint()
      ..color = Colors.white.withValues(alpha: .78)
      ..strokeWidth = math.max(4, size.width * .012)
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 5; i++) {
      final y = size.height * (.16 + i * .16);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + (i.isEven ? 8 : -5)), minorRoad);
    }
    for (var i = 0; i < 4; i++) {
      final x = size.width * (.14 + i * .23);
      canvas.drawLine(Offset(x, 0), Offset(x + (i.isEven ? -8 : 7), size.height), road);
    }

    final blocks = <RRect>[
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .18, size.height * .20, size.width * .18, size.height * .12), const Radius.circular(10)),
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .45, size.height * .09, size.width * .22, size.height * .15), const Radius.circular(12)),
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .67, size.height * .34, size.width * .20, size.height * .14), const Radius.circular(12)),
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .21, size.height * .55, size.width * .23, size.height * .14), const Radius.circular(12)),
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .49, size.height * .61, size.width * .18, size.height * .12), const Radius.circular(10)),
    ];
    for (var i = 0; i < blocks.length; i++) {
      canvas.drawRRect(blocks[i], i == 1 || i == 3 ? indoorPaint : blockPaint);
    }

    canvas.drawOval(Rect.fromLTWH(size.width * .03, size.height * .35, size.width * .22, size.height * .18), shadePaint);
    canvas.drawOval(Rect.fromLTWH(size.width * .72, size.height * .05, size.width * .24, size.height * .20), shadePaint);

    final fast = _path(size, 0);
    final comfort = _path(size, 1);
    final weather = _path(size, 2);

    void drawRoute(Path path, Color color, bool selected) {
      final outline = Paint()
        ..color = Colors.white.withValues(alpha: selected ? .95 : .58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 9 : 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final line = Paint()
        ..color = color.withValues(alpha: selected ? 1 : .30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 5.5 : 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, outline);
      canvas.drawPath(path, line);
    }

    drawRoute(fast, const Color(0xFF7185A3), selectedRoute == '빠른 길');
    drawRoute(comfort, const Color(0xFF9C6D84), selectedRoute == '쾌적한 길');
    drawRoute(weather, const Color(0xFF5F8C77), selectedRoute == '날씨 회피');

    final start = Offset(size.width * .09, size.height * .78);
    final end = Offset(size.width * .88, size.height * .18);
    canvas.drawCircle(start, 9, Paint()..color = const Color(0xFF5A91D8));
    canvas.drawCircle(start, 4, Paint()..color = Colors.white);
    canvas.drawCircle(end, 10, Paint()..color = const Color(0xFFBA6A88));
    canvas.drawCircle(end, 4, Paint()..color = Colors.white);

    _drawAmenity(canvas, Offset(size.width * .35, size.height * .42), Icons.water_drop_rounded, const Color(0xFF5E9EC5));
    _drawAmenity(canvas, Offset(size.width * .56, size.height * .30), Icons.wc_rounded, const Color(0xFF82739C));
    _drawAmenity(canvas, Offset(size.width * .74, size.height * .59), Icons.chair_alt_rounded, const Color(0xFF7E9275));
    _drawAmenity(canvas, Offset(size.width * .47, size.height * .68), Icons.apartment_rounded, const Color(0xFF9E7185));
  }

  Path _path(Size size, int type) {
    final p = Path()..moveTo(size.width * .09, size.height * .78);
    if (type == 0) {
      p.lineTo(size.width * .26, size.height * .64);
      p.lineTo(size.width * .38, size.height * .48);
      p.lineTo(size.width * .62, size.height * .39);
      p.lineTo(size.width * .88, size.height * .18);
    } else if (type == 1) {
      p.lineTo(size.width * .22, size.height * .69);
      p.lineTo(size.width * .33, size.height * .51);
      p.lineTo(size.width * .52, size.height * .54);
      p.lineTo(size.width * .66, size.height * .34);
      p.lineTo(size.width * .88, size.height * .18);
    } else {
      p.lineTo(size.width * .18, size.height * .70);
      p.lineTo(size.width * .32, size.height * .60);
      p.lineTo(size.width * .32, size.height * .35);
      p.lineTo(size.width * .54, size.height * .35);
      p.lineTo(size.width * .54, size.height * .20);
      p.lineTo(size.width * .74, size.height * .20);
      p.lineTo(size.width * .88, size.height * .18);
    }
    return p;
  }

  void _drawAmenity(Canvas canvas, Offset center, IconData icon, Color color) {
    canvas.drawCircle(center, 15, Paint()..color = Colors.white.withValues(alpha: .96));
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 18,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant ComfortMapPainter oldDelegate) =>
      oldDelegate.selectedRoute != selectedRoute || oldDelegate.mode != mode;
}
