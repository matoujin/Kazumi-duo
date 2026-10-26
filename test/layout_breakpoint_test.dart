import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/constants.dart';

void main() {
  group('LayoutBreakpoint', () {
    test('useNavigationRail is always true for primary destinations', () {
      // Duo outer (~466) and inner (~626) both use the trailing rail;
      // width is still passed from live LayoutBuilder / MediaQuery sizes.
      expect(LayoutBreakpoint.useNavigationRail(466), isTrue);
      expect(LayoutBreakpoint.useNavigationRail(626), isTrue);
      expect(LayoutBreakpoint.useNavigationRail(600), isTrue);
      expect(LayoutBreakpoint.useNavigationRail(320), isTrue);
    });

    test('isCompactWidth still tracks live window width', () {
      expect(LayoutBreakpoint.isCompactWidth(466), isTrue);
      expect(LayoutBreakpoint.isCompactWidth(599), isTrue);
      expect(LayoutBreakpoint.isCompactWidth(600), isFalse);
      expect(LayoutBreakpoint.isCompactWidth(626), isFalse);
    });

    test('useBottomSheet mirrors compact width', () {
      expect(LayoutBreakpoint.useBottomSheet(466), isTrue);
      expect(LayoutBreakpoint.useBottomSheet(626), isFalse);
    });

    test('animeGridColumns scales with window width', () {
      expect(LayoutBreakpoint.animeGridColumns(320), 2);
      expect(LayoutBreakpoint.animeGridColumns(400), 3);
      expect(LayoutBreakpoint.animeGridColumns(500), 4);
      expect(LayoutBreakpoint.animeGridColumns(700), 5);
      expect(LayoutBreakpoint.animeGridColumns(900), 6);
    });

    test('videoFillsWindow uses window aspect and explicit flags', () {
      expect(
        LayoutBreakpoint.videoFillsWindow(
          width: 466,
          height: 678,
          fullscreen: false,
          isPip: false,
        ),
        isFalse,
      );
      expect(
        LayoutBreakpoint.videoFillsWindow(
          width: 890,
          height: 626,
          fullscreen: false,
          isPip: false,
        ),
        isTrue,
      );
      expect(
        LayoutBreakpoint.videoFillsWindow(
          width: 466,
          height: 678,
          fullscreen: true,
          isPip: false,
        ),
        isTrue,
      );
      expect(
        LayoutBreakpoint.videoFillsWindow(
          width: 200,
          height: 300,
          fullscreen: false,
          isPip: true,
        ),
        isTrue,
      );
    });

    test('videoHasSidePanel requires immersion and usable width', () {
      expect(
        LayoutBreakpoint.videoHasSidePanel(
          width: 400,
          height: 300,
          fullscreen: false,
          isPip: false,
          hasPanel: true,
        ),
        isFalse, // landscape but narrower than 480
      );
      expect(
        LayoutBreakpoint.videoHasSidePanel(
          width: 890,
          height: 626,
          fullscreen: false,
          isPip: false,
          hasPanel: true,
        ),
        isTrue,
      );
      expect(
        LayoutBreakpoint.videoHasSidePanel(
          width: 890,
          height: 626,
          fullscreen: false,
          isPip: true,
          hasPanel: true,
        ),
        isFalse,
      );
      expect(
        LayoutBreakpoint.videoHasSidePanel(
          width: 890,
          height: 626,
          fullscreen: true,
          isPip: false,
          hasPanel: false,
        ),
        isFalse,
      );
    });
  });
}
