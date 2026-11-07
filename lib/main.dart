import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_chance/core/app_state.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/cloudy.dart';
import 'package:second_chance/ui/home.dart';
import 'package:second_chance/ui/support.dart';
import 'package:second_chance/ui/grow.dart';

final appRouteObserver = RouteObserver<PageRoute<dynamic>>();

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
                          const Cloudy(),
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
                          Cloudy(),
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
      title: 'Raise',
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      navigatorObservers: [appRouteObserver, LiquidGlassNavigatorObserver()],
      home: const MainShell(),
    ),
  );
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});
  @override
  Widget build(BuildContext context) => PreparePage(
    onSupport: () => openPage(context, const SupportDetailPage()),
    onGrow: () => openPage(
      context,
      Scaffold(
        appBar: AppBar(title: const Text('Your resilience')),
        body: const GrowPage(),
      ),
    ),
  );
}

Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
