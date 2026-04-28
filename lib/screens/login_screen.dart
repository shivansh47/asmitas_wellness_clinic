import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:diet_cure/core/providers/auth_provider.dart' as auth;
import 'package:diet_cure/core/models/app_user.dart';
import 'package:diet_cure/utils/app_styles.dart';
import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder or MediaQuery to handle responsiveness.
    // For desktop/web, show split screen. For mobile, show only form.
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppTheme.warmSand,
      body: Row(
        children: [
          // Left Panel: Hero Graphic (Desktop only)
          if (isDesktop)
            Expanded(
              flex: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background Image
                  Image(
                    image: const AssetImage('assets/images/login_screen_image.jpg'),
                    fit: BoxFit.cover,
                  ),
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.primaryDark.withValues(alpha: 0.9), Color(0xFF00A08A).withValues(alpha: 0.9)],
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(64.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Center(
                          child: Image(
                            image: const AssetImage('assets/images/lockups/15.png'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Spacer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Right Panel: Form Area
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 80.0 : 40.0,
                  vertical: 64.0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mobile logo (if needed)
                        if (!isDesktop) ...[
                          Text(
                            "Asmita's Wellness Clinic",
                            style: GoogleFonts.manrope(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkAzure,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 48),
                        ],

                        Text(
                          _isLogin ? 'Welcome back' : 'Create account',
                          style: GoogleFonts.quicksand(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkAzure,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin
                              ? 'Enter your account details.'
                              : 'Set up your account.',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: AppTheme.darkAzure.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Tab Toggle
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _TabButton(
                                  title: 'Login',
                                  isActive: _isLogin,
                                  onTap: () => setState(() => _isLogin = true),
                                ),
                              ),
                              Expanded(
                                child: _TabButton(
                                  title: 'Sign Up',
                                  isActive: !_isLogin,
                                  onTap: () => setState(() => _isLogin = false),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Form
                        Consumer<auth.AuthProvider>(
                          builder: (context, authProvider, _) {
                            // Reset loading state if auth status changed
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_isLoading && authProvider.status != auth.AuthStatus.loading) {
                                // Show error if login failed
                                if (authProvider.status == auth.AuthStatus.unauthenticated && 
                                    authProvider.errorMessage != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(authProvider.errorMessage!),
                                      backgroundColor: AppTheme.dustyRose,
                                    ),
                                  );
                                }
                                setState(() => _isLoading = false);
                              }
                            });
                            
                            return _AuthForm(key: ValueKey(_isLogin), isLogin: _isLogin);
                          },
                        ),

                        const SizedBox(height: 48),
                        
                        Center(
                          child: Text(
                            "© 2026 Asmita's Wellness Clinic. All rights reserved.",
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              color: AppTheme.darkAzure.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Tab Button Component ---
class _TabButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.warmSand : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppTheme.darkAzure.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? AppTheme.darkAzure : AppTheme.darkAzure.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

// --- Form Component ---
class _AuthForm extends StatefulWidget {
  final bool isLogin;
  const _AuthForm({Key? key, required this.isLogin}) : super(key: key);

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  // Email/Password fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  // OTP fields
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _showOtpVerification = false;
  String? _verificationId;
  int _otpCountdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startOtpCountdown() {
    setState(() => _otpCountdown = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _otpCountdown--;
        if (_otpCountdown == 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _submitEmail() async {
    final provider = context.read<auth.AuthProvider>();

    // Validate inputs
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: AppTheme.dustyRose,
        ),
      );
      return;
    }

    if (!widget.isLogin) {
      // Registration validation
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: AppTheme.dustyRose,
          ),
        );
        return;
      }
      if (_nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your name'),
            backgroundColor: AppTheme.dustyRose,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (widget.isLogin) {
        // Sign in with email
        await provider.signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      } else {
        // Register with email
        await provider.registerWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
          role: UserRole.client,
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (e is Exception) {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: AppTheme.dustyRose,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a phone number'),
          backgroundColor: AppTheme.dustyRose,
        ),
      );
      return;
    }

    final provider = context.read<auth.AuthProvider>();
    setState(() => _isLoading = true);

    try {
      final success = await provider.sendOtp(_phoneController.text);
      
      if (mounted && success) {
        setState(() {
          _verificationId = provider.verificationId;
          _showOtpVerification = true;
          _isLoading = false;
        });
        _startOtpCountdown();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to send OTP'),
            backgroundColor: AppTheme.dustyRose,
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.dustyRose,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty || _verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter OTP'),
          backgroundColor: AppTheme.dustyRose,
        ),
      );
      return;
    }

    final provider = context.read<auth.AuthProvider>();
    setState(() => _isLoading = true);

    try {
      await provider.verifyOtp(_otpController.text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.dustyRose,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== SECTION 1: Email & Password =====
        if (!_showOtpVerification) ...[
          // Full Name (Sign Up only)
          if (!widget.isLogin) ...[
            _buildLabel('FULL NAME'),
            const SizedBox(height: 8),
            _buildInputField(
              hint: 'E.g. Shivansh Dubey',
              icon: Icons.person_outline,
              controller: _nameController,
            ),
            const SizedBox(height: 16),
          ],

          // Email Address
          _buildLabel('EMAIL ADDRESS'),
          const SizedBox(height: 8),
          _buildInputField(
            hint: 'hello@example.com',
            icon: Icons.email_outlined,
            controller: _emailController,
          ),
          const SizedBox(height: 16),

          // Password
          _buildLabel('PASSWORD'),
          const SizedBox(height: 8),
          _buildInputField(
            hint: '••••••••',
            icon: Icons.lock_outline,
            isPassword: true,
            controller: _passwordController,
          ),

          // Confirm Password (Sign Up only)
          if (!widget.isLogin) ...[
            const SizedBox(height: 16),
            _buildLabel('CONFIRM PASSWORD'),
            const SizedBox(height: 8),
            _buildInputField(
              hint: '••••••••',
              icon: Icons.lock_outline,
              isPassword: true,
              controller: _confirmPasswordController,
            ),
          ],

          // Forgot Password (Login only)
          if (widget.isLogin) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot password?',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Email Submit Button
          _buildPrimaryButton(
            title: widget.isLogin ? 'Continue' : 'Create Account',
            isLoading: _isLoading,
            onTap: _submitEmail,
          ),

          // Only show OTP section on login and mobile platforms (Android/iOS)
          if (widget.isLogin && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) ...[
            const SizedBox(height: 32),
            _buildDivider(),
            const SizedBox(height: 32),
            // ===== SECTION 2: Phone & OTP =====
            Text(
              'Or sign in with phone',
              style: GoogleFonts.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkAzure,
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('PHONE NUMBER'),
            const SizedBox(height: 8),
            _buildInputField(
              hint: '+91 XXXXX XXXXX',
              icon: Icons.phone_outlined,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildSecondaryButton(
              title: 'Send OTP',
              isLoading: _isLoading,
              onTap: _sendOtp,
            ),
          ],
        ]
        // ===== OTP VERIFICATION VIEW =====
        else ...[
          Text(
            'Enter OTP',
            style: GoogleFonts.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkAzure,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A 6-digit code has been sent to ${_phoneController.text}',
            style: GoogleFonts.roboto(
              fontSize: 13,
              color: AppTheme.darkAzure.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          _buildLabel('OTP CODE'),
          const SizedBox(height: 8),
          _buildInputField(
            hint: '000000',
            icon: Icons.vpn_key_outlined,
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 12),
          // Countdown Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expires in: ${_otpCountdown}s',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: _otpCountdown > 0
                      ? AppTheme.darkAzure.withValues(alpha: 0.6)
                      : AppTheme.dustyRose,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_otpCountdown == 0)
                TextButton(
                  onPressed: _sendOtp,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Resend OTP',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          _buildPrimaryButton(
            title: 'Verify OTP',
            isLoading: _isLoading,
            onTap: _verifyOtp,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _showOtpVerification = false;
                _otpController.clear();
                _countdownTimer?.cancel();
                _otpCountdown = 0;
              });
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Back to email login',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.roboto(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AppTheme.onSurface,
      ),
    );
  }

  Widget _buildInputField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: GoogleFonts.roboto(
          fontSize: 14,
          color: AppTheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.roboto(
            fontSize: 14,
            color: AppTheme.onSurface.withValues(alpha: 0.3),
          ),
          prefixIcon: Icon(
            icon,
            color: AppTheme.darkAzure,
            size: 20,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          counterText: '',
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String title,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String title,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.surfaceContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                )
              : Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkAzure,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: AppTheme.darkAzure.withValues(alpha: 0.1),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: AppTheme.darkAzure.withValues(alpha: 0.4),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: AppTheme.darkAzure.withValues(alpha: 0.1),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}
