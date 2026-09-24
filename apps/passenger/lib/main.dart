import 'dart:convert';
import 'package:flutter/material.dart';

import 'core/auth/auth_service.dart';
import 'core/config/app_config.dart';
import 'core/country/country_config.dart';
import 'core/network/api_client.dart';

void main() {
  runApp(const DadiaPassengerApp());
}

final api = ApiClient();
final auth = AuthService(api);

class DadiaPassengerApp extends StatelessWidget {
  const DadiaPassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DADIA Passenger',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const LoginPage(),
    );
  }
}

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
    setState(() { loading = true; error = null; });
    try {
      await auth.login(phone.text.trim(), password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      if (mounted) setState(() => error = _cleanError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() { phone.dispose(); password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'ورود به دادیا',
      child: Column(
        children: [
          phoneField(phone),
          const SizedBox(height: 14),
          passwordField(password),
          if (error != null) errorText(error!),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : login,
              child: Text(loading ? 'در حال ورود...' : 'ورود'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: loading ? null : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RegisterPage()),
            ),
            child: const Text('حساب ندارم؛ ثبت نام می‌کنم'),
          ),
        ],
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  CountryConfig country = CountryConfigs.supported.first;
  bool loading = false;
  String? error;

  Future<void> register() async {
    setState(() { loading = true; error = null; });
    try {
      final p = phone.text.trim();
      if (!RegExp(r'^9\d{9}$').hasMatch(p) &&
          !RegExp(r'^09\d{9}$').hasMatch(p) &&
          !RegExp(r'^\+989\d{9}$').hasMatch(p)) {
        throw Exception('شماره موبایل معتبر ایران را وارد کنید');
      }
      if (password.text.length < 8) {
        throw Exception('رمز عبور باید حداقل ۸ کاراکتر باشد');
      }
      if (password.text != confirm.text) {
        throw Exception('تکرار رمز عبور یکسان نیست');
      }
      if (country.code != 'IR') {
        throw Exception('ثبت نام این نسخه در Backend فعلی فقط برای ایران فعال است');
      }

      await auth.register(p, password.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) setState(() => error = _cleanError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    phone.dispose(); password.dispose(); confirm.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'ثبت نام مسافر',
      back: true,
      child: Column(
        children: [
          DropdownButtonFormField<CountryConfig>(
            initialValue: country,
            decoration: const InputDecoration(
              labelText: 'کشور',
              border: OutlineInputBorder(),
            ),
            isExpanded: true,
            items: CountryConfigs.supported.map((c) => DropdownMenuItem(
              value: c,
              enabled: c.code == 'IR',
              child: Text(
                c.code == 'IR'
                    ? '${c.name} - فعال'
                    : '${c.name} - در انتظار فعال سازی Backend',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            )).toList(),
            onChanged: loading ? null : (value) { if (value != null) setState(() => country = value); },
          ),
          const SizedBox(height: 14),
          phoneField(phone, hint: 'مثال: 09121234567'),
          const SizedBox(height: 14),
          passwordField(password, label: 'رمز عبور'),
          const SizedBox(height: 14),
          passwordField(confirm, label: 'تکرار رمز عبور'),
          if (error != null) errorText(error!),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : register,
              child: Text(loading ? 'در حال ثبت نام...' : 'ثبت نام'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'این نسخه OTP را شبیه سازی نمی‌کند؛ Backend فعلی پس از ثبت نام Token واقعی برمی‌گرداند.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class AuthScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool back;
  const AuthScaffold({super.key, required this.title, required this.child, this.back = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), automaticallyImplyLeading: back),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.local_taxi, size: 72),
              const SizedBox(height: 16),
              const Text('DADIA Passenger', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              child,
              const SizedBox(height: 18),
              Text('Backend: ${AppConfig.apiBaseUrl}', textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
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
      setState(() => result = const JsonEncoder.withIndent('  ').convert(data));
    } catch (e) {
      setState(() => result = _cleanError(e));
    } finally {
      setState(() => loading = false);
    }
  }

  void logout() {
    auth.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دادیا | مسافر'),
        actions: [IconButton(onPressed: logout, icon: const Icon(Icons.logout))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(child: Padding(padding: EdgeInsets.all(18), child: Text(
            'به اپلیکیشن Passenger دادیا خوش آمدید.', style: TextStyle(fontSize: 18),
          ))),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: loading ? null : () => run(api.me), icon: const Icon(Icons.person), label: const Text('پروفایل من')),
          FilledButton.icon(onPressed: loading ? null : () => run(api.trips), icon: const Icon(Icons.history), label: const Text('سفرهای من')),
          FilledButton.icon(onPressed: loading ? null : () => run(api.activeTrip), icon: const Icon(Icons.navigation), label: const Text('سفر فعال')),
          const SizedBox(height: 18),
          if (loading) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: SelectableText(result))),
        ],
      ),
    );
  }
}

Widget phoneField(TextEditingController controller, {String hint = ''}) => TextField(
  controller: controller,
  keyboardType: TextInputType.phone,
  decoration: InputDecoration(labelText: 'شماره تلفن', hintText: hint, border: const OutlineInputBorder()),
);

Widget passwordField(TextEditingController controller, {String label = 'رمز عبور'}) => TextField(
  controller: controller,
  obscureText: true,
  decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
);

Widget errorText(String error) => Padding(
  padding: const EdgeInsets.only(top: 12),
  child: Text(error, style: const TextStyle(color: Colors.red)),
);

String _cleanError(Object e) => e.toString().replaceFirst('Exception: ', '');
