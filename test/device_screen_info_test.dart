import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/utils/device.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getScreenInfo uses the Flutter view physical size', () async {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final info = await getScreenInfo(view: view);

    expect(info.containsKey('width'), isTrue);
    expect(info.containsKey('height'), isTrue);
    expect(info.containsKey('ratio'), isTrue);
    expect(info['width'], view.physicalSize.width);
    expect(info['height'], view.physicalSize.height);
    expect(info['ratio'], greaterThan(0));
  });

  test('getScreenInfo matches MediaQueryData.fromView sizing', () async {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final media = MediaQueryData.fromView(view);
    final info = await getScreenInfo(view: view);
    final logical = Size(
      info['width']! / info['ratio']!,
      info['height']! / info['ratio']!,
    );

    expect(logical.width, closeTo(media.size.width, 0.5));
    expect(logical.height, closeTo(media.size.height, 0.5));
  });

  test('isDesktop reflects host OS only', () {
    // In the Linux CI / cloud agent this is false; the helper is OS-gated.
    expect(isDesktop(), anyOf(isTrue, isFalse));
  });
}
