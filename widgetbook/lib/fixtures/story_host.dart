import 'package:earth_nova/ui/design_system.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart';

Widget earthNovaStory({
  required Widget child,
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: overrides,
  child: ShadApp.custom(
    theme: AppDesignTheme.dark(),
    themeMode: ThemeMode.dark,
    appBuilder: (context) {
      const fallback = <String>['Noto Sans Symbols', 'Noto Color Emoji'];
      final theme = Theme.of(context);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
          primaryTextTheme: theme.primaryTextTheme.apply(
            fontFamilyFallback: fallback,
          ),
        ),
        supportedLocales: const [Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalShadLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: (context, content) => ShadAppBuilder(child: content),
        home: child,
      );
    },
  ),
);
