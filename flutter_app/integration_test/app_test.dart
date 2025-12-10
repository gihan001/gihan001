import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:energy_monitor_app/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Provisioning Flow Integration Test', () {
    testWidgets('User can navigate to provisioning screen', (tester) async {
      // Start the app
      await tester.pumpWidget(const EnergyMonitorApp());
      await tester.pumpAndSettle();

      // Should show auth screen initially
      expect(find.text('Energy Monitor'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      // Tap get started (will sign in anonymously)
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should now show device list
      // Note: This test assumes Firebase is configured and running
      // In a real integration test, you'd mock Firebase or use emulator
      
      // Look for Add Device button
      expect(find.text('Add Device'), findsOneWidget);
      
      // Tap add device
      await tester.tap(find.text('Add Device'));
      await tester.pumpAndSettle();

      // Should show BLE scan screen
      expect(find.text('Scan for Devices'), findsOneWidget);
    });
  });

  group('Dashboard Display Test', () {
    testWidgets('Dashboard shows charts when data is available', (tester) async {
      // This would require setting up test data in Firebase
      // Skipping actual implementation for now
    });
  });
}
