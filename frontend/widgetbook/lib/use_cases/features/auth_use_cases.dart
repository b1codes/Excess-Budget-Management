import 'package:flutter/material.dart';
import 'package:frontend/core/theme/refractive_glass.dart';
import 'package:frontend/features/auth/presentation/screens/login_screen.dart';
import 'package:frontend/features/auth/presentation/screens/profile_screen.dart';
import 'package:frontend/features/auth/presentation/screens/signup_screen.dart';
import 'package:frontend/features/auth/presentation/widgets/auth0_mock_sheet.dart';
import 'package:frontend/features/auth/presentation/widgets/branding_panel.dart';
import 'package:frontend/features/auth/presentation/widgets/login_form.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../../catalog/catalog_addons.dart';

@widgetbook.UseCase(name: 'Default', type: Auth0MockSheet)
Widget auth0MockSheet(BuildContext context) {
  return Align(
    alignment: Alignment.bottomCenter,
    child: Auth0MockSheet(onLogin: (_) {}),
  );
}

@widgetbook.UseCase(name: 'Default', type: BrandingPanel)
Widget brandingPanel(BuildContext context) => const BrandingPanel();

// Submitting dispatches AuthLoginRequested against the fake backend: pick
// the "Loading" scenario to see the busy state, "Error" for the snackbar.
@widgetbook.UseCase(name: 'In glass card', type: LoginForm)
Widget loginForm(BuildContext context) {
  return const ComponentFrame(child: RefractiveGlass(child: LoginForm()));
}

@widgetbook.UseCase(name: 'Screen', type: LoginScreen)
Widget loginScreen(BuildContext context) => const LoginScreen();

@widgetbook.UseCase(name: 'Screen', type: SignupScreen)
Widget signupScreen(BuildContext context) => const SignupScreen();

@widgetbook.UseCase(name: 'Screen', type: ProfileScreen)
Widget profileScreen(BuildContext context) => const ProfileScreen();
