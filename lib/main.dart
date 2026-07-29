import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/root_shell.dart';
import 'theme/app_theme.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(const AquaMetricsApp());
}

class AquaMetricsApp extends StatelessWidget {
  const AquaMetricsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AquaMetrics',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const RootShell(),
    );
  }
}
