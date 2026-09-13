import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/device/presentation/device_screen.dart';
import '../features/diagnostics/presentation/diagnostics_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/live_motion/presentation/live_motion_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/workout/presentation/workout_screen.dart';
import 'providers.dart';
import 'theme.dart';

class AppShellScaffold extends ConsumerWidget {
  final GoRouterState state;
  final Widget child;

  const AppShellScaffold({
    super.key,
    required this.state,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleTransport = ref.watch(bleTransportProvider);
    final String location = state.uri.toString();

    int currentIndex = 0;
    if (location.startsWith('/motion')) currentIndex = 1;
    if (location.startsWith('/workout')) currentIndex = 2;
    if (location.startsWith('/history')) currentIndex = 3;
    if (location.startsWith('/diagnostics')) currentIndex = 4;
    if (location.startsWith('/settings')) currentIndex = 5;

    return Scaffold(
      body: Column(
        children: [
          if (bleTransport.isMockMode)
            Container(
              width: double.infinity,
              color: AppTheme.warningAmber,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              child: const SafeArea(
                bottom: false,
                child: Text(
                  '⚡ SIMULATED DATA — MOCK BLE MODE ACTIVE ⚡',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.cardSurface,
        selectedItemColor: AppTheme.primaryCyan,
        unselectedItemColor: const Color(0xFF94A3B8),
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/device');
              break;
            case 1:
              context.go('/motion');
              break;
            case 2:
              context.go('/workout');
              break;
            case 3:
              context.go('/history');
              break;
            case 4:
              context.go('/diagnostics');
              break;
            case 5:
              context.go('/settings');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth_searching),
            label: 'Device',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Live Motion',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Workout',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bug_report),
            label: 'Diagnostics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

final appRouter = GoRouter(
  initialLocation: '/device',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShellScaffold(
        state: state,
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/device',
          name: 'device',
          builder: (context, state) => const DeviceScreen(),
        ),
        GoRoute(
          path: '/motion',
          name: 'motion',
          builder: (context, state) => const LiveMotionScreen(),
        ),
        GoRoute(
          path: '/workout',
          name: 'workout',
          builder: (context, state) => const WorkoutScreen(),
        ),
        GoRoute(
          path: '/history',
          name: 'history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/diagnostics',
          name: 'diagnostics',
          builder: (context, state) => const DiagnosticsScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);

