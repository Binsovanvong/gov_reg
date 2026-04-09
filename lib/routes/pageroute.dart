import 'package:flutter/material.dart';
import 'package:gov_reg/routes/approute.dart';
import 'package:gov_reg/screens/register.dart';
import 'package:gov_reg/screens/splahscreen.dart';
import 'package:gov_reg/screens/success.dart';
import 'package:gov_reg/screens/welcome.dart';

class PageRouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Approute.splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
        );

      case Approute.welcome:
        return MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        );

      case Approute.register:
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
        );
      case Approute.verifySuccessScreen:
        return MaterialPageRoute(
          builder: (_) => const RegisterSuccessMixedScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text("Route not found"),
            ),
          ),
        );
    }
  }
}