import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gov_reg/routes/approute.dart';
import 'package:gov_reg/routes/pageroute.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.kantumruyProTextTheme(),
      ),
      onGenerateRoute: PageRouteGenerator.generateRoute,
      initialRoute: Approute.splash,
    );
  }
}
