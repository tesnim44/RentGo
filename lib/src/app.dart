import 'package:flutter/material.dart';

import 'api_client.dart';
import 'pages/landing_page.dart';
import 'pages/reset_password_page.dart';
import 'session_controller.dart';
import 'theme.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.session,
    required super.child,
  });

  final ApiClient api;
  final SessionController session;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return api != oldWidget.api || session != oldWidget.session;
  }
}

class RentGoApp extends StatefulWidget {
  const RentGoApp({super.key});

  @override
  State<RentGoApp> createState() => _RentGoAppState();
}

class _RentGoAppState extends State<RentGoApp> {
  late final ApiClient _apiClient = ApiClient();
  late final SessionController _sessionController = SessionController();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      api: _apiClient,
      session: _sessionController,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'RentGo Tunisia',
        theme: buildRentGoTheme(),
        home: _initialPage(),
      ),
    );
  }

  Widget _initialPage() {
    final token = Uri.base.queryParameters['resetToken'];
    return token == null || token.isEmpty
        ? const LandingPage()
        : ResetPasswordPage(token: token);
  }
}
