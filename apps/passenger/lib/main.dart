import 'core/config/app_config.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const apiBase = AppConfig.apiBaseUrl;

void main() {
  runApp(const DadiaPassengerApp());
}

class DadiaPassengerApp extends StatelessWidget {
  const DadiaPassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DADIA Passenger',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const LoginPage(),
    );
  }
}

class ApiClient {
  String? accessToken;

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  Future<Map<String, dynamic>> login(
      String phone, String password) async {
    final response = await http.post(
      Uri.parse('$apiBase/auth/login'),
      headers: headers,
      body: jsonEncode({
        'phone': phone,
        'password': password,
      }),
    );

    final data = _json(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error'] ?? 'ورود ناموفق بود');
    }

    accessToken = data['accessToken'] ??
        data['access_token'] ??
        data['token'] ??
        data['data']?['accessToken'];

    if (accessToken == null) {
      throw Exception('توکن ورود از سرور دریافت نشد');
    }

    return data;
  }

  Future<Map<String, dynamic>> me() async {
    final response = await http.get(
      Uri.parse('$apiBase/auth/me'),
      headers: headers,
    );
    final data = _json(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error'] ?? 'دریافت پروفایل ناموفق بود');
    }
    return data;
  }

  Future<Map<String, dynamic>> trips() async {
    final response = await http.get(
      Uri.parse('$apiBase/passenger/trips'),
      headers: headers,
    );
    final data = _json(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error'] ?? 'دریافت سفرها ناموفق بود');
    }
    return data;
  }

  Future<Map<String, dynamic>> activeTrip() async {
    final response = await http.get(
      Uri.parse('$apiBase/passenger/trips/active'),
      headers: headers,
    );
    final data = _json(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error'] ?? 'دریافت سفر فعال ناموفق بود');
    }
    return data;
  }

  Map<String, dynamic> _json(http.Response response) {
    if (response.body.isEmpty) return {};
    try {
      final value = jsonDecode(response.body);
      return value is Map<String, dynamic> ? value : {'data': value};
    } catch (_) {
      return {'error': response.body};
    }
  }
}

final api = ApiClient();

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phone = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await api.login(phone.text.trim(), password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دادیا')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.local_taxi, size: 72),
              const SizedBox(height: 16),
              const Text(
                'DADIA Passenger',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'شماره تلفن',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'رمز عبور',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: loading ? null : login,
                  child: Text(loading ? 'در حال ورود...' : 'ورود'),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Backend: $apiBase',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String result = 'برای مشاهده اطلاعات یکی از گزینه‌ها را انتخاب کنید.';
  bool loading = false;

  Future<void> run(Future<Map<String, dynamic>> Function() action) async {
    setState(() => loading = true);
    try {
      final data = await action();
      setState(() {
        result = const JsonEncoder.withIndent('  ').convert(data);
      });
    } catch (e) {
      setState(() => result = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => loading = false);
    }
  }

  void logout() {
    api.accessToken = null;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دادیا | مسافر'),
        actions: [
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
            tooltip: 'خروج',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'به اپلیکیشن Passenger دادیا خوش آمدید.',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading ? null : () => run(api.me),
            icon: const Icon(Icons.person),
            label: const Text('پروفایل من'),
          ),
          FilledButton.icon(
            onPressed: loading ? null : () => run(api.trips),
            icon: const Icon(Icons.history),
            label: const Text('سفرهای من'),
          ),
          FilledButton.icon(
            onPressed: loading ? null : () => run(api.activeTrip),
            icon: const Icon(Icons.navigation),
            label: const Text('سفر فعال'),
          ),
          const SizedBox(height: 18),
          if (loading) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(result),
            ),
          ),
        ],
      ),
    );
  }
}
