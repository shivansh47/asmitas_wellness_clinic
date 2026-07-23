
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diet_cure/core/models/app_user.dart';
import 'package:diet_cure/core/services/auth_service.dart';
import 'package:diet_cure/core/services/user_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';

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

  final _logger = Logger();

  AuthProvider() {
    _init();
  }

  void _init() {
    _authStateSubscription = _authService.authStateChanges.listen((firebaseUser) async {
      if(firebaseUser == null){
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
      } else if (firebaseUser.uid.isEmpty) {
          return;
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
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try{
      _logger.d("Registering user with email in authprovider");
      await _authService.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );

      final firebaseUser = await _authService.getCurrentAuthUser();
      if(firebaseUser == null){
        throw StateError("Auth user is missing immediately after registration");
      }

      AppUser? appUser;
      for(var i=0; i<20; i++){
        await Future.delayed(const Duration(milliseconds: 500));
        appUser = await _userService.fetchByUid(firebaseUser.uid);
        if(appUser != null) break;
      }

      if(appUser == null){
        throw StateError(
          'Registration successful in auth, but the user profile was not created in time.'
          'Check firebase functions: log --only onUserCreated'
        );
      }

      if(displayName.isNotEmpty && appUser.displayName != displayName){
        await FirebaseFirestore.instance
          .collection("users")
          .doc(firebaseUser.uid)
          .update({'displayName': displayName});
        appUser = await _userService.fetchByUid(firebaseUser.uid) ?? appUser;
      }

      _currentUser = appUser;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Registration failed. Try Again';
      _logger.d('registerWithEmail failed: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try{
      _logger.d("signing in with email in the authprovider");
      final credential = await _authService.signInWithEmail(email, password);

      // Manually fetch and set user instead of waiting for stream
      if (credential.user != null) {
        final appUser = await _userService.fetchByUid(credential.user!.uid);
        if (appUser == null) {
          await _authService.signOut();
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'No Account found.';
        } else {
          _currentUser = appUser;
          _status = AuthStatus.authenticated;
        }
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Login failed. Check email and password.';
    }
    notifyListeners();
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