import 'dart:io';
import 'dart:ui' show FlutterView, Size;

import 'package:flutter/widgets.dart';

/// Whether the current platform is a desktop OS (not a window-size class).
bool isDesktop() {
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

/// Logical height of the active Flutter view (not the hardware display).
///
/// Prefer this over [platformDispatcher.displays] on foldables / Split View /
/// Stage Manager, where the window can be smaller than the physical screen
/// and can change live (e.g. iPhone Duo fold ↔ unfold).
Future<bool> isLowResolution() async {
  if (Platform.isMacOS) {
    return false;
  }
  final screenInfo = await getScreenInfo();
  return screenInfo['height']! / screenInfo['ratio']! < 900;
}

/// Active window metrics for the primary Flutter view.
///
/// Returns physical pixel [width]/[height] of the view and its DPR [ratio].
/// Uses [FlutterView.physicalSize] so fold/unfold and multitasking resize
/// are reflected; do not use [PlatformDispatcher.displays].
Future<Map<String, double>> getScreenInfo({FlutterView? view}) async {
  final resolved =
      view ?? WidgetsBinding.instance.platformDispatcher.views.first;
  final mediaQuery = MediaQueryData.fromView(resolved);
  final Size physical = resolved.physicalSize;
  return {
    'width': physical.width,
    'height': physical.height,
    'ratio': mediaQuery.devicePixelRatio,
  };
}
