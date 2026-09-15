import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/ui/product_surfaces/auth/screens/loading_screen.dart';
import 'package:earth_nova/ui/product_surfaces/auth/screens/login_screen.dart';
import 'package:earth_nova_widgetbook/fixtures/auth_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/story_host.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: LoadingScreen,
  path: '[Product Surfaces]/Auth',
)
Widget loadingScreenHappyPath(BuildContext context) => earthNovaStory(
  overrides: authStoryOverrides(),
  child: const LoadingScreen(),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: LoginScreen,
  path: '[Product Surfaces]/Auth',
)
Widget loginScreenHappyPath(BuildContext context) =>
    earthNovaStory(overrides: authStoryOverrides(), child: const LoginScreen());

@widgetbook.UseCase(
  name: '10 Submitting',
  type: LoginScreen,
  path: '[Product Surfaces]/Auth',
)
Widget loginScreenSubmitting(BuildContext context) => earthNovaStory(
  overrides: authStoryOverrides(state: const AuthState.loading()),
  child: const LoginScreen(),
);

@widgetbook.UseCase(
  name: '20 Submit Error',
  type: LoginScreen,
  path: '[Product Surfaces]/Auth',
)
Widget loginScreenSubmitError(BuildContext context) => earthNovaStory(
  overrides: authStoryOverrides(
    submittedState: const AuthState.error(
      'Phone sign-in is unavailable. Try again.',
    ),
  ),
  child: const _LoginSubmitErrorStory(),
);

class _LoginSubmitErrorStory extends StatefulWidget {
  const _LoginSubmitErrorStory();

  @override
  State<_LoginSubmitErrorStory> createState() => _LoginSubmitErrorStoryState();
}

class _LoginSubmitErrorStoryState extends State<_LoginSubmitErrorStory> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _visitDescendants(context, (element) {
        final widget = element.widget;
        if (widget is TextField) {
          widget.controller?.text = '5065550101';
        }
      });
      _visitDescendants(context, (element) {
        final widget = element.widget;
        if (widget is ElevatedButton) widget.onPressed?.call();
      });
    });
  }

  @override
  Widget build(BuildContext context) => const LoginScreen();
}

void _visitDescendants(
  BuildContext context,
  void Function(Element element) visit,
) {
  void walk(Element element) {
    visit(element);
    element.visitChildElements(walk);
  }

  context.visitChildElements(walk);
}
