import 'models.dart';

class SessionController {
  UserSession? _session;

  UserSession? get session => _session;
  bool get isAuthenticated => _session != null;
  String? get token => _session?.token;
  AppUser? get user => _session?.user;

  void setSession(UserSession session) {
    _session = session;
  }

  void updateWalletBalance(double balance) {
    final current = _session;
    if (current == null) return;
    _session = UserSession(
      token: current.token,
      user: current.user.copyWith(walletBalance: balance),
    );
  }

  void clear() {
    _session = null;
  }
}
