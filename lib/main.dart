import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/capture_screen.dart';
import 'screens/root_shell.dart';
import 'theme/app_theme.dart';
import 'vision/roboflow_detector.dart';
import 'vision/yolo_detector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  // Prefer the Roboflow workflow (cloud inference) when an API key is present.
  // Fall back to the on-device YOLO model so the app still counts without a
  // key or network. Both are non-fatal on failure: the detector returns empty
  // and the operator can still pick a photo and correct manually.
  //
  // The key is baked in at compile time:
  //   flutter run --dart-define=ROBOFLOW_API_KEY=your_key_here
  final roboflowKey = roboflowApiKey;
  if (roboflowKey != null) {
    globalRoboflowDetector = RoboflowDetector(apiKey: roboflowKey);
  } else {
    YoloDetector.create()
        .then((d) {
          globalYoloDetector = d;
        })
        .catchError((Object _) {
          // Model load failed — the app still runs, detection returns empty.
        });
  }
  runApp(const AquaMetricsApp());
}

class AquaMetricsApp extends StatelessWidget {
  const AquaMetricsApp({super.key, this.pickImage});

  final ImagePickerCallback? pickImage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AquaMetrics',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: RootShell(pickImage: pickImage),
    );
  }
}
