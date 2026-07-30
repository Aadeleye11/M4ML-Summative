import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// change this to wherever the API is actually running
//   - chrome/web, desktop, ios sim: http://127.0.0.1:8000
//   - android emulator: http://10.0.2.2:8000
//   - real device: http://<your computer's LAN IP>:8000
// if running on chrome, use a fixed port so it matches ALLOWED_ORIGINS in main.py:
//   flutter run -d chrome --web-port=3000
const String apiBaseUrl = 'http://127.0.0.1:8000';

const List<String> regionOptions = ['North', 'South', 'East', 'West'];
const List<String> soilTypeOptions = [
  'Clay',
  'Loam',
  'Sandy',
  'Silt',
  'Peaty',
  'Chalky',
];
const List<String> cropOptions = [
  'Wheat',
  'Rice',
  'Maize',
  'Barley',
  'Soybean',
  'Cotton',
];
const List<String> weatherOptions = ['Sunny', 'Rainy', 'Cloudy'];

void main() {
  runApp(const CropYieldApp());
}

class CropYieldApp extends StatelessWidget {
  const CropYieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crop Yield Predictor',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
      home: PredictionPage(),
    );
  }
}

class PredictionPage extends StatefulWidget {
  PredictionPage({super.key, http.Client? client}) : client = client ?? http.Client();

  // so tests can swap in a MockClient instead of hitting the real network
  final http.Client client;

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final _formKey = GlobalKey<FormState>();

  String? _region;
  String? _soilType;
  String? _crop;
  String? _weatherCondition;
  bool? _fertilizerUsed;
  bool? _irrigationUsed;

  final _rainfallCtrl = TextEditingController();
  final _temperatureCtrl = TextEditingController();

  bool _loading = false;
  String? _output;
  bool _outputIsError = false;

  @override
  void dispose() {
    _rainfallCtrl.dispose();
    _temperatureCtrl.dispose();
    super.dispose();
  }

  String? _validateRange(String? value, double min, double max, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return '$label must be a number';
    }
    if (parsed < min || parsed > max) {
      return '$label must be between $min and $max';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _output = 'Please correct the highlighted fields before predicting.';
        _outputIsError = true;
      });
      return;
    }

    final payload = {
      'Region': _region,
      'Soil_Type': _soilType,
      'Crop': _crop,
      'Rainfall_mm': double.parse(_rainfallCtrl.text.trim()),
      'Temperature_Celsius': double.parse(_temperatureCtrl.text.trim()),
      'Fertilizer_Used': _fertilizerUsed,
      'Irrigation_Used': _irrigationUsed,
      'Weather_Condition': _weatherCondition,
    };

    setState(() {
      _loading = true;
      _output = null;
      _outputIsError = false;
    });

    try {
      final response = await widget.client
          .post(
            Uri.parse('$apiBaseUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final predicted = (data['predicted_yield_tons_per_hectare'] as num).toStringAsFixed(4);
        setState(() {
          _output = 'Predicted yield: $predicted tons/hectare';
          _outputIsError = false;
        });
      } else if (response.statusCode == 422) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = data['detail'];
        final message = (detail is List)
            ? detail.map((d) => '${(d['loc'] as List).last}: ${d['msg']}').join('\n')
            : detail.toString();
        setState(() {
          _output = 'One or more values were rejected:\n$message';
          _outputIsError = true;
        });
      } else {
        setState(() {
          _output = 'Server error (${response.statusCode}): ${response.body}';
          _outputIsError = true;
        });
      }
    } catch (e) {
      setState(() {
        _output = 'Could not reach the API at $apiBaseUrl:\n$e';
        _outputIsError = true;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  DropdownButtonFormField<String> _categoryDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? '$label is required' : null,
    );
  }

  DropdownButtonFormField<bool> _boolDropdown({
    required String label,
    required bool? value,
    required ValueChanged<bool?> onChanged,
  }) {
    return DropdownButtonFormField<bool>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: true, child: Text('Yes')),
        DropdownMenuItem(value: false, child: Text('No')),
      ],
      onChanged: onChanged,
      validator: (v) => v == null ? '$label is required' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Crop Yield Predictor'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            // One input widget per prediction variable (8 total): dropdowns for the
            // 6 fixed-choice fields (closed enums on the API side, so a typo like
            // "north" vs "North" would otherwise fail case-sensitive validation),
            // text fields for the 2 continuous numeric ranges below.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _categoryDropdown(
                  label: 'Region',
                  value: _region,
                  options: regionOptions,
                  onChanged: (v) => setState(() => _region = v),
                ),
                const SizedBox(height: 12),
                _categoryDropdown(
                  label: 'Soil Type',
                  value: _soilType,
                  options: soilTypeOptions,
                  onChanged: (v) => setState(() => _soilType = v),
                ),
                const SizedBox(height: 12),
                _categoryDropdown(
                  label: 'Crop',
                  value: _crop,
                  options: cropOptions,
                  onChanged: (v) => setState(() => _crop = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rainfallCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Rainfall (mm)',
                    hintText: '100 - 1000',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => _validateRange(v, 100, 1000, 'Rainfall (mm)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _temperatureCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Temperature (°C)',
                    hintText: '15 - 40',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => _validateRange(v, 15, 40, 'Temperature (°C)'),
                ),
                const SizedBox(height: 12),
                _boolDropdown(
                  label: 'Fertilizer Used',
                  value: _fertilizerUsed,
                  onChanged: (v) => setState(() => _fertilizerUsed = v),
                ),
                const SizedBox(height: 12),
                _boolDropdown(
                  label: 'Irrigation Used',
                  value: _irrigationUsed,
                  onChanged: (v) => setState(() => _irrigationUsed = v),
                ),
                const SizedBox(height: 12),
                _categoryDropdown(
                  label: 'Weather Condition',
                  value: _weatherCondition,
                  options: weatherOptions,
                  onChanged: (v) => setState(() => _weatherCondition = v),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Predict', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _outputIsError
                        ? Colors.red.withValues(alpha: 0.08)
                        : Colors.green.withValues(alpha: 0.08),
                    border: Border.all(
                      color: _outputIsError ? Colors.red : Colors.green,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _output ?? 'Prediction will appear here.',
                    style: TextStyle(
                      fontSize: 16,
                      color: _outputIsError ? Colors.red.shade900 : Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
