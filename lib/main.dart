import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_chance/core/app_state.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/home.dart';
import 'package:second_chance/ui/support.dart';
import 'package:second_chance/ui/grow.dart';

void main() {
  final logs = PrintLogCollector();
  runZonedGuarded(
    () {
      if (kDebugMode) {
        MarionetteBinding.ensureInitialized(
          MarionetteConfiguration(logCollector: logs),
        );
      } else {
        WidgetsFlutterBinding.ensureInitialized();
      }
      final previousError = FlutterError.onError;
      FlutterError.onError = (details) {
        logs.addLog(details.toString());
        previousError?.call(details);
      };
      runApp(
        kDebugMode
            ? const MarionetteDeviceConfig(child: _Bootstrap())
            : const _Bootstrap(),
      );
    },
    (error, stack) {
      logs.addLog('$error\n$stack');
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        logs.addLog(line);
        parent.print(zone, line);
      },
    ),
  );
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<SharedPreferences> _preferences = SharedPreferences.getInstance();
  AppState? _state;
  @override
  void dispose() {
    _state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SharedPreferences>(
    future: _preferences,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        _state ??= AppState(snapshot.data!);
        return SecondChanceApp(state: _state!);
      }
      return MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Center(
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Pip(),
                          const Text('We couldn’t open your saved progress.'),
                          const SizedBox(height: 20),
                          PrimaryButton(
                            label: 'Try again',
                            onPressed: () => setState(
                              () => _preferences =
                                  SharedPreferences.getInstance(),
                            ),
                          ),
                        ],
                      )
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Pip(),
                          SizedBox(height: 20),
                          CircularProgressIndicator(),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class SecondChanceApp extends StatelessWidget {
  const SecondChanceApp({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Second Chance',
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      navigatorObservers: [LiquidGlassNavigatorObserver()],
      home: const MainShell(),
    ),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  void select(int index) => setState(() => _index = index);
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          if (state.persistenceError != null)
            SafeArea(
              bottom: false,
              child: MaterialBanner(
                content: Text(state.persistenceError!),
                actions: [
                  TextButton(
                    onPressed: state.persist,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                TickerMode(
                  enabled: _index == 0,
                  child: PreparePage(
                    onSupport: () => select(1),
                    onGrow: () => select(2),
                  ),
                ),
                TickerMode(enabled: _index == 1, child: const SupportPage()),
                TickerMode(enabled: _index == 2, child: const GrowPage()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NativeLiquidGlassUtils.supportsLiquidGlass
          ? LiquidGlassTabBar(
              height: 64,
              currentIndex: _index,
              selectedItemColor: AppColors.accent(context),
              onTabSelected: select,
              items: const [
                LiquidGlassTabItem(
                  label: 'Prepare',
                  icon: NativeLiquidGlassIcon.sfSymbol('sun.horizon'),
                  selectedIcon: NativeLiquidGlassIcon.sfSymbol(
                    'sun.horizon.fill',
                  ),
                ),
                LiquidGlassTabItem(
                  label: 'Support',
                  icon: NativeLiquidGlassIcon.sfSymbol('heart'),
                  selectedIcon: NativeLiquidGlassIcon.sfSymbol('heart.fill'),
                ),
                LiquidGlassTabItem(
                  label: 'Grow',
                  icon: NativeLiquidGlassIcon.sfSymbol('leaf'),
                  selectedIcon: NativeLiquidGlassIcon.sfSymbol('leaf.fill'),
                ),
              ],
            )
          : SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.line(context)),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: _TabItem(
                          index: i,
                          selected: _index == i,
                          onPressed: () => select(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.index,
    required this.selected,
    required this.onPressed,
  });
  final int index;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: TextButton(
      key: ValueKey('tab_$index'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? AppColors.accent(context)
            : AppColors.muted(context),
        backgroundColor: selected
            ? AppColors.canvas(context)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            [
              Icons.wb_twilight_rounded,
              Icons.favorite_border_rounded,
              Icons.spa_outlined,
            ][index],
            size: 23,
          ),
          const SizedBox(height: 3),
          Text(
            ['Prepare', 'Support', 'Grow'][index],
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
