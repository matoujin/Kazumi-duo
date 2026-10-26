import 'package:flutter/material.dart';
import 'package:kazumi/utils/constants.dart';

typedef VideoPlayerLayout = ({bool fillsWindow, bool hasSidePanel});

/// Fullscreen fills the available window; rotation belongs to the OS.
///
/// Layout follows the **current window bounds** so fold/unfold on iPhone Duo
/// (and Split View) can switch between stacked phone chrome and immersed /
/// side-panel layouts without restarting.
class VideoPageLayout extends StatelessWidget {
  const VideoPageLayout({
    super.key,
    required this.fullscreen,
    required this.isPip,
    required this.playerBuilder,
    required this.tabs,
    this.sidePanel,
  });

  final bool fullscreen;
  final bool isPip;
  final Widget Function(BuildContext context, VideoPlayerLayout layout)
      playerBuilder;
  final Widget tabs;
  final Widget? sidePanel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final fillsWindow = LayoutBreakpoint.videoFillsWindow(
        width: width,
        height: height,
        fullscreen: fullscreen,
        isPip: isPip,
      );
      final hasSidePanel = LayoutBreakpoint.videoHasSidePanel(
        width: width,
        height: height,
        fullscreen: fullscreen,
        isPip: isPip,
        hasPanel: sidePanel != null,
      );
      final player = Builder(
        builder: (context) => playerBuilder(context, (
          fillsWindow: fillsWindow,
          hasSidePanel: hasSidePanel,
        )),
      );
      return SafeArea(
        top: !fillsWindow,
        bottom: !fillsWindow,
        left: !fillsWindow,
        right: !fillsWindow,
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            Column(
              children: [
                Flexible(
                  flex: fillsWindow ? 1 : 0,
                  child: SizedBox(
                    height: fillsWindow ? double.infinity : null,
                    width: double.infinity,
                    // Keep 16:9 only in the stacked (non-immersive) chrome;
                    // when filling the window, let the player surface own fit.
                    child: fillsWindow
                        ? player
                        : AspectRatio(aspectRatio: 16 / 9, child: player),
                  ),
                ),
                if (!fillsWindow) Expanded(child: tabs),
              ],
            ),
            if (hasSidePanel) sidePanel!,
          ],
        ),
      );
    });
  }
}
