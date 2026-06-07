import 'package:fitness_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the fitness dashboard and log sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FitnessTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('FitTrack'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Daily goals'), findsOneWidget);
    expect(find.text('Weekly active minutes'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();

    expect(find.text('Log activity'), findsOneWidget);
    expect(find.text('Exercise type'), findsOneWidget);
    expect(find.text('Save log'), findsOneWidget);
  });
}
