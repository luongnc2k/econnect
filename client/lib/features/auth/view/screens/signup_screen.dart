// ignore_for_file: avoid_print

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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String selectedRole = 'student';

  @override
  void dispose() {
    nameController.dispose();
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
          // When Google sign-up returns a token, the router redirects itself.
          if (data.token.isNotEmpty) return;
          showSnackBar(context, strings.accountCreated);
          context.go(AppRoutes.login);
        },
        error: (error, st) {
          if (!mounted) return;
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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: LanguageSelector(),
              ),
              const SizedBox(height: 12),
              const AuthLogo(
                heightFraction: 0.18,
                minHeight: 90,
                maxHeight: 160,
              ),

              const SizedBox(height: 20),

              Text(
                strings.signupTitle,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                strings.signupSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 24),
              CustomField(
                hintText: strings.name,
                controller: nameController,
                requiredMessage: strings.requiredField(strings.name),
              ),
              const SizedBox(height: 15),
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
              const SizedBox(height: 20),
              RadioGroup<String>(
                groupValue: selectedRole,
                onChanged: (val) {
                  if (val != null) setState(() => selectedRole = val);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text(strings.studentRole),
                        value: 'student',
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text(strings.teacherRole),
                        value: 'teacher',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AuthGradientButton(
                buttonText: strings.signUp,
                onTap: () async {
                  if (formKey.currentState!.validate()) {
                    await ref
                        .read(authViewModelProvider.notifier)
                        .signUpUser(
                          name: nameController.text.trim(),
                          email: emailController.text.trim(),
                          password: passwordController.text,
                          role: selectedRole,
                        );
                  } else {
                    showSnackBar(context, strings.missingFields);
                  }
                },
              ),
              const SizedBox(height: 15),
              GoogleSignInButton(
                label: strings.googleSignUp,
                onTap: () async {
                  await ref
                      .read(authViewModelProvider.notifier)
                      .loginWithGoogle(role: selectedRole, allowSignup: true);
                },
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  context.go(AppRoutes.login);
                },
                child: RichText(
                  text: TextSpan(
                    text: strings.alreadyHaveAccount,
                    style: Theme.of(context).textTheme.titleMedium,
                    children: [
                      TextSpan(
                        text: strings.signIn,
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
}
