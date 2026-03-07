import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/app_theme.dart';

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin  => _currentUser?.role == AppConstants.roleAdmin;

  AuthProvider() {
    final existing = _authService.currentUser;
    if (existing != null) {
      _authService.getUser(existing.id).then((u) {
        _currentUser = u;
        notifyListeners();
      });
    }
    _authService.authStateChanges.listen((event) async {
      final u = event.session?.user;
      if (u == null) {
        _currentUser = null;
      } else {
        _currentUser = await _authService.getUser(u.id);
      }
      notifyListeners();
    });
  }

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _setError(String? v) { _errorMessage = v; notifyListeners(); }

  Future<bool> login(String email, String password) async {
    _setLoading(true); _setError(null);
    try {
      _currentUser = await _authService.login(email: email, password: password);
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _setError(_friendlyError(e.message));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register({
    required String name, required String email,
    required String password, required String phone, String role = AppConstants.roleUser,
  }) async {
    _setLoading(true); _setError(null);
    try {
      _currentUser = await _authService.register(
          name: name, email: email, password: password, phone: phone, role: role);
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _setError(_friendlyError(e.message));
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    try {
      await _authService.resetPassword(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> refreshUser() async {
    if (_currentUser != null) {
      _currentUser = await _authService.getUser(_currentUser!.id);
      notifyListeners();
    }
  }

  String _friendlyError(String msg) {
    if (msg.contains('Invalid login'))      return 'Incorrect email or password.';
    if (msg.contains('already registered')) return 'This email is already registered.';
    if (msg.contains('Password should'))    return 'Password must be at least 6 characters.';
    return msg;
  }
}
