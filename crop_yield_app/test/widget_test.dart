import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crop_yield_app/main.dart';

Future<void> _selectDropdown(WidgetTester tester, String label, String optionText) async {
  await tester.ensureVisible(find.widgetWithText(DropdownButtonFormField<String>, label));
  await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionText).last);
  await tester.pumpAndSettle();
}

Future<void> _selectBoolDropdown(WidgetTester tester, String label, String optionText) async {
  await tester.ensureVisible(find.widgetWithText(DropdownButtonFormField<bool>, label));
  await tester.tap(find.widgetWithText(DropdownButtonFormField<bool>, label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionText).last);
  await tester.pumpAndSettle();
}

Future<void> _fillValidForm(WidgetTester tester) async {
  await _selectDropdown(tester, 'Region', 'North');
  await _selectDropdown(tester, 'Soil Type', 'Loam');
  await _selectDropdown(tester, 'Crop', 'Wheat');
  await tester.enterText(find.widgetWithText(TextFormField, 'Rainfall (mm)'), '850');
  await tester.enterText(find.widgetWithText(TextFormField, 'Temperature (°C)'), '24.5');
  await _selectBoolDropdown(tester, 'Fertilizer Used', 'Yes');
  await _selectBoolDropdown(tester, 'Irrigation Used', 'Yes');
  await _selectDropdown(tester, 'Weather Condition', 'Sunny');
  await tester.pump();
}

Future<void> _tapPredict(WidgetTester tester) async {
  final predictButton = find.widgetWithText(ElevatedButton, 'Predict');
  await tester.ensureVisible(predictButton);
  await tester.tap(predictButton);
}

void main() {
  testWidgets('Prediction page shows all input fields, button, and output area', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(CropYieldApp());

    expect(find.text('Crop Yield Predictor'), findsWidgets);
    // 6 category/bool dropdowns (Region, Soil Type, Crop, Fertilizer, Irrigation, Weather)
    // + 2 free-text numeric fields (Rainfall, Temperature) = 8 inputs, one per model variable.
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(4));
    expect(find.byType(DropdownButtonFormField<bool>), findsNWidgets(2));
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(ElevatedButton, 'Predict'), findsOneWidget);
    expect(find.text('Prediction will appear here.'), findsOneWidget);
  });

  testWidgets('Predict with empty fields shows a validation message instead of crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(CropYieldApp());

    await _tapPredict(tester);
    await tester.pump();

    expect(
      find.text('Please correct the highlighted fields before predicting.'),
      findsOneWidget,
    );
  });

  testWidgets('Successful API response displays the predicted yield', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/predict');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['Region'], 'North');
      expect(body['Rainfall_mm'], 850.0);
      expect(body['Fertilizer_Used'], true);
      return http.Response(
        jsonEncode({'predicted_yield_tons_per_hectare': 7.4566}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(home: PredictionPage(client: mockClient)));
    await _fillValidForm(tester);
    await _tapPredict(tester);
    await tester.pumpAndSettle();

    expect(find.text('Predicted yield: 7.4566 tons/hectare'), findsOneWidget);
  });

  testWidgets('422 API response displays the rejection reason', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'detail': [
            {
              'loc': ['body', 'Rainfall_mm'],
              'msg': 'Input should be less than or equal to 1000',
            },
          ],
        }),
        422,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(home: PredictionPage(client: mockClient)));
    await _fillValidForm(tester);
    await _tapPredict(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('One or more values were rejected:\nRainfall_mm: Input should be less than or equal to 1000'),
      findsOneWidget,
    );
  });
}
