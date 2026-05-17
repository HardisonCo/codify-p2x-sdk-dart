import 'package:codify_p2x_sdk/codify_p2x_sdk.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Entry point for the codify_p2x_sdk example app.
///
/// Demonstrates the minimum viable wiring of [P2xClient]:
///
///   * A fake token closure (returns a placeholder bearer token).
///   * A fake subproject domain closure.
///   * A single button that hits `/health` on the configured base URL via
///     the SDK's exposed [Dio] instance.
///
/// Run with a custom base URL via:
///
/// ```bash
/// flutter run --dart-define=P2X_BASE_URL=https://api.project20x.com/api
/// ```
void main() {
  runApp(const ExampleApp());
}

/// Root widget for the example app.
class ExampleApp extends StatelessWidget {
  /// Construct.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'codify_p2x_sdk example',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const HomePage(),
    );
  }
}

/// The single screen of the example app.
class HomePage extends StatefulWidget {
  /// Construct.
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _baseUrl = String.fromEnvironment(
    'P2X_BASE_URL',
    defaultValue: 'https://api.project20x.com/api',
  );

  late final P2xClient _client = P2xClient(
    config: P2xClientConfig(
      baseUrl: _baseUrl,
      getToken: () => 'example-fake-token',
      getDomain: () => 'example.codify.ai',
    ),
  );

  String _result = 'Tap "Call /health" to send a request.';
  bool _busy = false;

  Future<void> _callHealth() async {
    setState(() {
      _busy = true;
      _result = 'Calling $_baseUrl/health ...';
    });
    try {
      // ignore: invalid_use_of_visible_for_testing_member
      final response = await _client.dio.get<dynamic>('/health');
      setState(() => _result = 'Status ${response.statusCode}');
    } on DioException catch (e) {
      setState(() => _result = 'DioException: ${e.type}');
    } on Object catch (e) {
      setState(() => _result = '${e.runtimeType}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('codify_p2x_sdk example')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Base URL: $_baseUrl', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy ? null : _callHealth,
                child: const Text('Call /health'),
              ),
              const SizedBox(height: 24),
              Text(_result, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
