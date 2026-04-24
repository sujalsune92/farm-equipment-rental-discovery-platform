import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/app_theme.dart';

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();
  final _storageService = StorageService();
  final Completer<void> _bootstrapped = Completer<void>();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin  => _currentUser?.role == AppConstants.roleAdmin;
  bool get isBootstrapped => _bootstrapped.isCompleted;

  AuthProvider() {
    _bootstrap();
    _authService.authStateChanges.listen((event) async {
      final u = event.session?.user;
      if (u == null) {
        _currentUser = null;
      } else {
        _currentUser = await _authService.resolveUserProfile(
          u,
          fallbackEmail: u.email ?? '',
        );
      }
      _completeBootstrapOnce();
      notifyListeners();
    });
  }

  Future<void> _bootstrap() async {
    final existing = _authService.currentUser;
    if (existing != null) {
      _currentUser = await _authService.resolveUserProfile(
        existing,
        fallbackEmail: existing.email ?? '',
      );
    }
    _completeBootstrapOnce();
    notifyListeners();
  }

  void _completeBootstrapOnce() {
    if (!_bootstrapped.isCompleted) {
      _bootstrapped.complete();
    }
  }

  Future<void> waitForBootstrap() => _bootstrapped.future;

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _setError(String? v) { _errorMessage = v; notifyListeners(); }

  Future<bool> login(String email, String password) async {
    _setLoading(true); _setError(null);
    try {
      _currentUser = await _authService.login(email: email, password: password);
      if (_currentUser == null) {
        _setError('Unable to load your profile after sign-in. Check the users table in Supabase.');
        _setLoading(false);
        return false;
      }
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

  Future<bool> updateProfileImage(File image) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    try {
      final url = await _storageService.uploadProfileImage(image, _currentUser!.id);
      await _authService.updateProfile(_currentUser!.id, {'profile_image_url': url});
      _currentUser = _currentUser!.copyWith(profileImageUrl: url);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  String _friendlyError(String msg) {
    if (msg.contains('Invalid login'))      return 'Incorrect email or password.';
    if (msg.contains('already registered')) return 'This email is already registered.';
    if (msg.contains('Password should'))    return 'Password must be at least 6 characters.';
    if (msg.toLowerCase().contains('too many requests') ||
        msg.toLowerCase().contains('rate limit') ||
        msg.contains('429')) {
      return 'Too many attempts right now. Please wait a few minutes and try again.';
    }
    return msg;
  }
}
