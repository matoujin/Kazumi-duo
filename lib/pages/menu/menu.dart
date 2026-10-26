import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/pages/menu/route_visibility.dart';
import 'package:kazumi/pages/router.dart';
import 'package:kazumi/utils/constants.dart';

class ScaffoldMenu extends StatefulWidget {
  const ScaffoldMenu({super.key, required this.location});

  final String location;

  @override
  State<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class _ScaffoldMenu extends State<ScaffoldMenu> with RouteAware {
  final _outletKey = GlobalKey<RouterOutletState>();
  late int _selectedIndex = menu.indexForPath(widget.location);
  DateTime? _lastExitPromptAt;

  /// The shell sits at the bottom of the root stack and stays mounted while
  /// other pages cover it, so it publishes that state for its subtree.
  bool _isCovered = false;

  @override
  void didUpdateWidget(covariant ScaffoldMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _selectedIndex = menu.indexForPath(widget.location);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      rootRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    rootRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() => _setCovered(true);

  @override
  void didPopNext() => _setCovered(false);

  void _setCovered(bool value) {
    if (!mounted || _isCovered == value) {
      return;
    }
    setState(() => _isCovered = value);
  }

  void _selectDestination(int index) {
    _lastExitPromptAt = null;
    if (index == _selectedIndex) {
      return;
    }
    final outlet = _outletKey.currentState;
    if (outlet == null) return;
    outlet.navigate('/tab${menu.getPath(index)}/');
    setState(() => _selectedIndex = index);
  }

  void _handleSystemBack(BuildContext context) {
    if (_outletKey.currentState?.maybePop() ?? false) {
      _lastExitPromptAt = null;
      return;
    }

    if (_selectedIndex != 0) {
      _selectDestination(0);
      return;
    }

    final now = DateTime.now();
    final lastPromptAt = _lastExitPromptAt;
    if (lastPromptAt == null ||
        now.difference(lastPromptAt) > const Duration(seconds: 2)) {
      _lastExitPromptAt = now;
      KazumiDialog.showToast(message: '再按一次退出应用', context: context);
      return;
    }

    _lastExitPromptAt = null;
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return RouteVisibility(
      isCovered: _isCovered,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _handleSystemBack(context);
          }
        },
        // Always trailing NavigationRail (Duo outer + inner). Compact width
        // only thins labels so the 5.4" outer screen keeps usable content.
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _sideMenu(
              context,
              _selectedIndex,
              compact: LayoutBreakpoint.isCompactWidth(constraints.maxWidth),
            );
          },
        ),
      ),
    );
  }

  Widget _outlet(BuildContext context, {BorderRadius? borderRadius}) {
    Widget child = NotificationListener<NavigationNotification>(
      // A non-poppable outlet must not override the shell's PopScope state.
      onNotification: (notification) => !notification.canHandlePop,
      child: RouterOutlet(key: _outletKey),
    );
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius, child: child);
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }

  Widget _sideMenu(
    BuildContext context,
    int selectedIndex, {
    required bool compact,
  }) {
    // Rail on the trailing (right) edge; round the content edge that meets it.
    const borderRadius = BorderRadius.only(
      topRight: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Row(
        children: [
          // Leading content needs the macOS traffic-light inset; the
          // trailing rail does not.
          Expanded(
            child: EmbeddedNativeControlArea(
              child: _outlet(context, borderRadius: borderRadius),
            ),
          ),
          NavigationRail(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            // Narrow outer display: icons-only rail to preserve content width.
            minWidth: compact ? 56 : 72,
            groupAlignment: 1,
            leading: FloatingActionButton(
              elevation: 0,
              heroTag: null,
              mini: compact,
              onPressed: () => context.pushNamed('/search/'),
              child: const Icon(Icons.search),
            ),
            labelType: compact
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.selected,
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                selectedIcon: Icon(Icons.home),
                icon: Icon(Icons.home_outlined),
                label: Text('推荐'),
              ),
              NavigationRailDestination(
                selectedIcon: Icon(Icons.timeline),
                icon: Icon(Icons.timeline_outlined),
                label: Text('时间表'),
              ),
              NavigationRailDestination(
                selectedIcon: Icon(Icons.favorite),
                icon: Icon(Icons.favorite_border),
                label: Text('追番'),
              ),
              NavigationRailDestination(
                selectedIcon: Icon(Icons.settings),
                icon: Icon(Icons.settings_outlined),
                label: Text('我的'),
              ),
            ],
            selectedIndex: selectedIndex,
            onDestinationSelected: _selectDestination,
          ),
        ],
      ),
    );
  }
}
