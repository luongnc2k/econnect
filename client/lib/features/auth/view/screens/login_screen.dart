import 'package:client/core/theme/app_pallete.dart';
import 'package:client/core/utils.dart';
import 'package:client/core/widgets/loader.dart';
import 'package:client/features/auth/view/screens/signup_screen.dart';
import 'package:client/features/auth/view/widgets/auth_gradient_button.dart';
import 'package:client/features/auth/view/widgets/custom_field.dart';
import 'package:client/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:client/features/home/view/screen/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

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
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (_) => false,
          );
        },
        error: (error, st) {
          showSnackBar(context, error.toString());
        },
        loading: () {},
      );
    });

    return Scaffold(
      appBar: AppBar(),
      body: isLoading
          ? Loader()
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      // 🔥 LOGO
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          "images/logo.png", // ⚠ nếu pubspec khai báo - assets/
                          height: 200,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 30),

                      CustomField(
                        hintText: 'Email',
                        controller: emailController,
                      ),

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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupPage(),
                            ),
                          );
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
            ),
    );
  }
}
