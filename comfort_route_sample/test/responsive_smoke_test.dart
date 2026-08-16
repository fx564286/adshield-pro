import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comfort_route_sample/main.dart';

void main() {
  const sizes = <Size>[
    Size(360, 800),
    Size(393, 873),
    Size(412, 915),
    Size(480, 1040),
  ];

  for (final size in sizes) {
    testWidgets('renders pleasant UI without exceptions at ${size.width}x${size.height}',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ComfortRouteApp());
      await tester.pumpAndSettle();

      expect(find.text('쾌적길'), findsOneWidget);
      expect(find.text('덜 덥고, 덜 힘든 길'), findsOneWidget);
      expect(find.text('어디로 갈까요?'), findsOneWidget);
      expect(find.text('길찾기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
