import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gov_reg/routes/approute.dart';
import 'package:gov_reg/screens/login.dart';
import 'package:gov_reg/screens/register.dart';
import 'package:gov_reg/screens/splahscreen.dart';
import 'package:gov_reg/screens/success.dart';
import 'package:gov_reg/screens/welcome.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  debugShowCheckedModeBanner: false,
  initialRoute: Approute.splash,
  theme: ThemeData(
    useMaterial3: true,
    textTheme: GoogleFonts.notoSansKhmerTextTheme(),
  ),

  // ✅ Keep normal routes here (NO success route here)
  routes: {
    Approute.splash: (context) => const SplashScreen(),
    Approute.welcome: (context) => const WelcomeScreen(),
    Approute.register: (context) => const RegisterScreen(),
    Approute.login: (context) => const LoginPage(),
  },

  // ✅ Put this right here
  onGenerateRoute: (settings) {
    if (settings.name == Approute.verifySuccessScreen) {
      final args = settings.arguments as Map<String, dynamic>;

      return MaterialPageRoute(
        builder: (_) => RegisterSuccessScreen(code: args['code'], token: args['token']),
      );
    }
    return null;
  },
);
  }
}
