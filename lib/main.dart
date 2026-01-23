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
      initialRoute: '/register',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansKhmerTextTheme(),
      ),
      routes: {
        Approute.splash: (context) => const SplashScreen(),
        Approute.welcome: (context) => const WelcomeScreen(),
        Approute.verifySuccessScreen: (context) => const VerifySuccessScreen(),
        Approute.register: (context) => const RegisterScreen(),
        Approute.login: (context) => const LoginPage(),
      },
    );
  }
}
