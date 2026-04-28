import 'package:diet_cure/core/models/app_user.dart';
import 'package:diet_cure/core/providers/auth_provider.dart' as auth;
import 'package:diet_cure/screens/admin_screen.dart';
import 'package:diet_cure/screens/client_screen.dart';
import 'package:diet_cure/screens/dietitian_screen.dart';
import 'package:diet_cure/screens/login_screen.dart';
import 'package:diet_cure/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatelessWidget{
    const AuthWrapper({super.key});

    @override
    Widget build(BuildContext context){
        return Consumer<auth.AuthProvider>(
            builder: (context, authProvider, _){
                if(authProvider.status == auth.AuthStatus.initial){
                  return const SplashScreen();
                }

                if(authProvider.status == auth.AuthStatus.unauthenticated){
                  return const LoginScreen();
                }

                if(authProvider.currentUser == null){
                  return const LoginScreen();
                }

                if(authProvider.currentUser!.role == UserRole.unknown){
                  return const LoginScreen();
                }

                return switch(authProvider.currentUser!.role){
                  UserRole.admin => const AdminScreen(),
                  UserRole.dietitian => const DietitianScreen(),
                  UserRole.client => const ClientScreen(),
                  UserRole.unknown => const LoginScreen(),
                };
            }
        );
    }
}