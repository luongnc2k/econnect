import 'package:client/core/router/app_router.dart';
import 'package:client/core/theme/app_pallete.dart';
import 'package:client/core/utils.dart';
import 'package:client/features/auth/view/widgets/auth_gradient_button.dart';
import 'package:client/features/auth/view/widgets/auth_logo.dart';
import 'package:client/features/auth/view/widgets/auth_scroll_body.dart';
import 'package:client/features/auth/view/widgets/custom_field.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/profile/viewmodel/my_profile_viewmodel.dart';
import 'package:client/features/auth/viewmodel/auth_viewmodel.dart';
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
              const AuthLogo(),

              const SizedBox(height: 20),

              Text(
                'Đăng nhập',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Chào mừng bạn quay lại!',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 28),

              CustomField(hintText: 'Email', controller: emailController),

              const SizedBox(height: 15),

              CustomField(
                hintText: 'Password',
                controller: passwordController,
                isObscureText: true,
              ),

              const SizedBox(height: 25),

              AuthGradientButton(
                buttonText: 'Sign In',
                onTap: () async {
                  if (formKey.currentState!.validate()) {
                    await ref
                        .read(authViewModelProvider.notifier)
                        .loginUser(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                        );
                  } else {
                    showSnackBar(context, 'Missing fields!');
                  }
                },
              ),

              const SizedBox(height: 25),

              GestureDetector(
                onTap: () {
                  context.push(AppRoutes.signup);
                },
                child: RichText(
                  text: TextSpan(
                    text: 'Don\'t have an account? ',
                    style: Theme.of(context).textTheme.titleMedium,
                    children: [
                      TextSpan(
                        text: 'Sign Up',
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
    if (profile is StudentMyProfileModel && !profile.hasBankAccount) {
      return AppRoutes.studentBankSetup;
    }
    return AppRoutes.homeForRole(role);
  }
}
