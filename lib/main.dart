import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'screens/splash_screen.dart';
import 'services/access_guard.dart';
import 'theme/app_theme.dart';
import 'widgets/receptionist_quick_bubble.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const EyeSaasTabletApp());
}

class EyeSaasTabletApp extends StatelessWidget {
  const EyeSaasTabletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eyenosis — Tablet',
      debugShowCheckedModeBanner: false,
      navigatorKey: AccessGuard.instance.navigatorKey,
      navigatorObservers: [ReceptionBubbleObserver.instance],
      theme: AppTheme.light,
      builder: (context, child) => Stack(children: [
        ?child,
        const ReceptionQuickBubble(),
      ]),
      home: const SplashScreen(),
    );
  }
}
