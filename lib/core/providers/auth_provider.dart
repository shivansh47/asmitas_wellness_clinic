
import 'dart:async';

import 'package:diet_cure/core/models/app_user.dart';
import 'package:diet_cure/core/services/auth_service.dart';
import 'package:diet_cure/core/services/user_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum AuthStatus {initial, loading, authenticated, unauthenticated}

class AuthProvider extends ChangeNotifier{
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  AppUser? _currentUser;
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  String? _verificationId;
  late StreamSubscription _authStateSubscription;

  AppUser? get currentUser => _currentUser;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get verificationId => _verificationId;

  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isDietitian => _currentUser?.role == UserRole.dietitian;
  bool get isClient => _currentUser?.role == UserRole.client;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authStateSubscription = _authService.authStateChanges.listen((firebaseUser) async {
      if(firebaseUser == null){
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
      } else {
        final appUser = await _userService.fetchByUid(firebaseUser.uid);

        if(appUser == null){
          await _authService.signOut();
          _currentUser = null;
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'No Account found.';
        } else {
          _currentUser = appUser;
          _status = AuthStatus.authenticated;
          _errorMessage = null;
        }
      }
      notifyListeners();
    });
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required UserRole role
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try{
      await _authService.registerWithEmail(
        email: email, 
        password: password, 
        displayName: displayName, 
        role: role
      );
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Registration failed. Try Again';
      notifyListeners();
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try{
      await _authService.signInWithEmail(email, password);
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Login failed. Check email and password.';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try{
      await _authService.signOut();
    } catch (e) {
      _errorMessage = 'Sign out failed.';
    }
    notifyListeners();
  }

  Future<bool> sendOtp(String phoneNumber) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      bool otpSent = false;
      await _authService.sendOtp(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) {
          _verificationId = verificationId;
          _status = AuthStatus.unauthenticated;
          otpSent = true;
          notifyListeners();
        },
        onError: (error) {
          _status = AuthStatus.unauthenticated;
          _errorMessage = error;
          notifyListeners();
        },
      );
      
      // Wait a bit for the callback to be processed
      await Future.delayed(const Duration(milliseconds: 100));
      return otpSent && _verificationId != null;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Error sending OTP: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> verifyOtp(String smsCode) async{
    if(_verificationId == null){
      _errorMessage = 'Verification ID not found. Send OTP first.';
      notifyListeners();
      throw Exception(_errorMessage);
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try{
      final credential = await _authService.verifyOtp(
        verificationId: _verificationId!, 
        smsCode: smsCode
      );
      
      // Check if user exists in Firestore, if not create them as client
      final user = credential.user;
      if (user != null) {
        final existingUser = await _userService.fetchByUid(user.uid);
        if (existingUser == null) {
          // Create new user with client role
          await _authService.saveUserToFirestore(user, UserRole.client);
        }
      }
      // Status will be updated by the auth state listener
    } catch (e){
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Verification failed. Invalid OTP.';
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose(){
    _authStateSubscription.cancel();
    super.dispose();
  }
  
}