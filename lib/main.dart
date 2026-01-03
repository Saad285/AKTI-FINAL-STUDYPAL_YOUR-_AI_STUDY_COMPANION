import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:gcr/firebase_options.dart';
import 'package:gcr/studypal/Authentication/loginpage.dart';
import 'package:gcr/studypal/students/homepage.dart';
import 'package:gcr/studypal/theme/app_colors.dart';
import 'package:gcr/studypal/providers/app_providers.dart';
import 'package:gcr/studypal/common/splash_screen.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exceptionAsString()}');
        if (details.stack != null) {
          debugPrint(details.stack.toString());
        }
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('PlatformDispatcher error: $error');
        debugPrint(stack.toString());
        return true;
      };

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      runApp(MultiProvider(providers: appProviders, child: const MyApp()));
    },
    (error, stack) {
      debugPrint('Zoned error: $error');
      debugPrint(stack.toString());
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

  void _onSplashComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'StudyPal',
          theme: ThemeData(
            primaryColor: AppColors.primary,
            scaffoldBackgroundColor: AppColors.background,
            useMaterial3: true,
          ),
          home: _showSplash
              ? SplashScreen(onComplete: _onSplashComplete)
              : StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, snapshot) {
                    debugPrint(
                      'AUTH STATE: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, error: ${snapshot.error}',
                    );

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Scaffold(
                        backgroundColor: const Color(0xFFE0F7FA),
                        body: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      debugPrint('❌ Auth stream error: ${snapshot.error}');
                      return const LoginScreen();
                    }

                    if (snapshot.hasData) {
                      debugPrint(
                        'Showing homepage for user: ${snapshot.data?.uid}',
                      );
                      return const StudentHomepage();
                    } else {
                      debugPrint('No user, showing login screen');
                      return const LoginScreen();
                    }
                  },
                ),
        );
      },
    );
  }
}
