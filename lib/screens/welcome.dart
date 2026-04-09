import 'package:flutter/material.dart';
import 'package:gov_reg/routes/approute.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color _navy = Color(0xFF0A2D66);
  static const Color _gold = Color(0xFFDFB73B);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700 || size.width < 360;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
            Color(0xFFFFCA28),
            Color(0xFFFFCA28),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            _buildBackgroundGlow(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              _buildHeroCard(isSmall),
                              SizedBox(height: isSmall ? 24 : 30),
                              _buildRegisterButton(context),
                              SizedBox(height: isSmall ? 20 : 26),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          left: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
        Positioned(
          top: 140,
          right: -50,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          bottom: -70,
          left: 30,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.lightBlueAccent.withOpacity(0.07),
            ),
          ),
        ),
      ],
    );
  }

  
  Widget _buildHeroCard(bool isSmall) {
    final double logoSize = isSmall ? 220 : 220;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isSmall ? 20 : 24,
        isSmall ? 24 : 28,
        isSmall ? 20 : 24,
        isSmall ? 24 : 28,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: Colors.white,
        border: Border.all(
          color: Color(0xFFDFB73B)
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              // boxShadow: [
              //   BoxShadow(
              //     color: Colors.white.withOpacity(0.10),
              //     blurRadius: 30,
              //     spreadRadius: 4,
              //   ),
              //   BoxShadow(
              //     color: Colors.black.withOpacity(0.14),
              //     blurRadius: 24,
              //     offset: const Offset(0, 12),
              //   ),
              // ],
            ),
              child: Image.asset(
                'assets/icon/MOI-EES (IOS).png',
                fit: BoxFit.contain, 
                width: logoSize ,
                height: logoSize,
              ),
          ),
          SizedBox(height: isSmall ? 20 : 24),
          Text(
            'សូមស្វាគមន៍មកកាន់',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _gold,
              fontSize: isSmall ? 24 : 30,
              fontWeight: FontWeight.bold,
              fontFamily: 'khmer moul light',
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'កម្មវិធី MOI-EES',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _gold,
              fontSize: isSmall ? 24 : 30,
              fontWeight: FontWeight.w900,
              fontFamily: 'khmer moul light',
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'ប្រព័ន្ធគ្រប់គ្រងការចេញចូលយានយន្តក្រសួងមហាផ្ទៃ\nប្រើប្រាស់ប្រកបដោយភាពងាយស្រួល និងទំនើប',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _gold.withOpacity(0.92),
              fontSize: isSmall ? 12 : 12,
              height: 1.55,
              fontWeight: FontWeight.w500,
              fontFamily: 'KantumruyPro',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFCA28),
            Color(0xFFFFCA28),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushNamed(context, Approute.register);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.12),
          foregroundColor: _navy,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.app_registration_rounded,
              size: 22,
              color: _navy,
            ),
            SizedBox(width: 10),
            Text(
              'ចូលប្រើប្រាស់',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'KantumruyPro',
                color: _navy,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.10),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.shield_rounded,
              color: Colors.white.withOpacity(0.94),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'General Department of Digital Technology and Media',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 13.5,
                  height: 1.45,
                  fontFamily: 'KantumruyPro',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}