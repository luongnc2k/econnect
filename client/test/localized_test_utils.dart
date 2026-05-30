import 'package:client/core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const testLocale = Locale('vi');
const testSupportedLocales = appSupportedLocales;
const testLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];
