import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/video/video_page_layout.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester tester, {
    required Size size,
    required bool fullscreen,
    Widget? sidePanel,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: VideoPageLayout(
            fullscreen: fullscreen,
            isPip: false,
            sidePanel: sidePanel,
            tabs: const SizedBox(key: Key('tabs'), height: 100),
            playerBuilder: (context, layout) => ColoredBox(
              key: Key(
                'player-${layout.fillsWindow}-${layout.hasSidePanel}',
              ),
              color: Colors.black,
              child: Text(
                'fills=${layout.fillsWindow} side=${layout.hasSidePanel}',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('stacked phone portrait keeps tabs and 16:9 player',
      (tester) async {
    await pumpAt(
      tester,
      size: const Size(466, 678),
      fullscreen: false,
      sidePanel: const SizedBox(key: Key('side')),
    );
    expect(find.text('fills=false side=false'), findsOneWidget);
    expect(find.byKey(const Key('tabs')), findsOneWidget);
    expect(find.byType(AspectRatio), findsOneWidget);
  });

  testWidgets('landscape Duo inner immerses and shows side panel',
      (tester) async {
    await pumpAt(
      tester,
      size: const Size(890, 626),
      fullscreen: false,
      sidePanel: const SizedBox(key: Key('side'), width: 200, height: 400),
    );
    expect(find.text('fills=true side=true'), findsOneWidget);
    expect(find.byKey(const Key('tabs')), findsNothing);
    expect(find.byKey(const Key('side')), findsOneWidget);
    expect(find.byType(AspectRatio), findsNothing);
  });

  testWidgets('explicit fullscreen immerses on compact portrait',
      (tester) async {
    await pumpAt(
      tester,
      size: const Size(466, 678),
      fullscreen: true,
      sidePanel: const SizedBox(key: Key('side'), width: 200, height: 400),
    );
    // Compact portrait fullscreen immerses but width < 480 → no side panel.
    expect(find.text('fills=true side=false'), findsOneWidget);
  });
}
