import 'package:client/core/localization/app_language.dart';
import 'package:client/core/localization/language_controls.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/core/theme/app_pallete.dart';
import 'package:client/core/utils.dart';
import 'package:client/features/auth/view/widgets/auth_gradient_button.dart';
import 'package:client/features/auth/view/widgets/auth_logo.dart';
import 'package:client/features/auth/view/widgets/auth_scroll_body.dart';
import 'package:client/features/auth/view/widgets/custom_field.dart';
import 'package:client/features/auth/view/widgets/google_sign_in_button.dart';
import 'package:client/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/profile/viewmodel/my_profile_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool _handledLoginRoute = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      authViewModelProvider.select((val) => val?.isLoading == true),
    );
    final strings = ref.watch(appStringsProvider);

    ref.listen(authViewModelProvider, (_, next) {
      next?.when(
        data: (data) {
          if (!mounted) return;
          if (_handledLoginRoute) {
            return;
          }
          _handledLoginRoute = true;
          context.go(_resolvePostLoginRoute(data.role));
        },
        error: (error, st) {
          if (!mounted) return;
          _handledLoginRoute = false;
          showSnackBar(context, error.toString());
        },
        loading: () {},
      );
    });

    final titleSize = (MediaQuery.of(context).size.width * 0.09).clamp(
      28.0,
      40.0,
    );

    return Scaffold(
      body: AuthScrollBody(
        isLoading: isLoading,
        child: Form(
          key: formKey,
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: LanguageSelector(),
              ),

              const SizedBox(height: 12),

              const AuthLogo(),

              const SizedBox(height: 20),

              Text(
                strings.loginTitle,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                strings.loginSubtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 28),

              CustomField(
                hintText: strings.email,
                controller: emailController,
                requiredMessage: strings.requiredField(strings.email),
              ),

              const SizedBox(height: 15),

              CustomField(
                hintText: strings.password,
                controller: passwordController,
                isObscureText: true,
                requiredMessage: strings.requiredField(strings.password),
              ),

              const SizedBox(height: 25),

              AuthGradientButton(
                buttonText: strings.signIn,
                onTap: () async {
                  if (formKey.currentState!.validate()) {
                    await ref
                        .read(authViewModelProvider.notifier)
                        .loginUser(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                        );
                  } else {
                    showSnackBar(context, strings.missingFields);
                  }
                },
              ),

              const SizedBox(height: 15),

              GoogleSignInButton(
                label: strings.googleSignIn,
                onTap: () async {
                  _handledLoginRoute = false;
                  await ref
                      .read(authViewModelProvider.notifier)
                      .loginWithGoogle();
                },
              ),

              const SizedBox(height: 25),

              GestureDetector(
                onTap: () {
                  context.push(AppRoutes.signup);
                },
                child: RichText(
                  text: TextSpan(
                    text: strings.dontHaveAccount,
                    style: Theme.of(context).textTheme.titleMedium,
                    children: [
                      TextSpan(
                        text: strings.signUp,
                        style: TextStyle(
                          color: Pallete.gradient2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolvePostLoginRoute(String role) {
    final profile = ref.read(myProfileViewModelProvider).profile;
    if (profile is TeacherMyProfileModel && !profile.hasPayoutBankAccount) {
      return AppRoutes.teacherBankSetup;
    }
    return AppRoutes.homeForRole(role);
  }
}
