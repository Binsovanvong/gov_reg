import 'package:flutter/material.dart';
import 'package:gov_reg/routes/approute.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  static const Color _gold = Color(0xFFDFB73B);
  static const Color _goldBright = Color(0xFFF4D46A);
  static const Color _goldDeep = Color(0xFFB88A16);
  static const Color _goldSoftText = Color(0xFF9C7A16);
  static const Color _bgTop = Color(0xFFFFD54F);
  static const Color _bgBottom = Color(0xFFFFB300);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700 || size.width < 360;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            _buildBackgroundDecoration(),
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
                              SizedBox(height: isSmall ? 28 : 34),
                              _buildRegisterButton(context),
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

  // ================= BACKGROUND =================
  Widget _buildBackgroundDecoration() {
    return Stack(
      children: [
        Positioned(
          top: -60,
          left: -40,
          child: _circle(180, Colors.white.withOpacity(0.12)),
        ),
        Positioned(
          top: 80,
          right: -50,
          child: _circle(220, Colors.white.withOpacity(0.08)),
        ),
        Positioned(
          bottom: 120,
          left: -30,
          child: _circle(160, _goldBright.withOpacity(0.15)),
        ),
        Positioned(
          bottom: -70,
          right: -20,
          child: _circle(220, Colors.white.withOpacity(0.10)),
        ),
      ],
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  // ================= HERO =================
  Widget _buildHeroCard(bool isSmall) {
    final double logoSize = isSmall ? 120 : 140;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFCF2), Color(0xFFFFF7E1)],
        ),
        border: Border.all(color: _goldBright.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPremiumLogo(logoSize),
          const SizedBox(height: 18),

          Text(
            'សូមស្វាគមន៍មកកាន់',
            style: TextStyle(
              color: _goldDeep,
              fontSize: isSmall ? 24 : 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'khmer moul light',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'កម្មវិធី MOI-EES',
            style: TextStyle(
              foreground: Paint()
                ..shader = const LinearGradient(
                  colors: [
                    Color(0xFFF4D46A),
                    Color(0xFFDFB73B),
                    Color(0xFFB88A16),
                  ],
                ).createShader(const Rect.fromLTWH(0, 0, 300, 70)),
              fontSize: isSmall ? 26 : 30,
              fontWeight: FontWeight.w900,
              fontFamily: 'khmer moul light',
            ),
          ),

          const SizedBox(height: 16),

          Container(
            width: 80,
            height: 4,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_goldBright, _gold, _goldDeep],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'ប្រព័ន្ធគ្រប់គ្រងការចេញចូលយានយន្តក្រសួងមហាផ្ទៃ\nប្រើប្រាស់ប្រកបដោយភាពងាយស្រួល ទំនើប និងមានសុវត្ថិភាព',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _goldSoftText,
              fontSize: 12, 
              height: 1.6,    
              fontFamily: 'KantumruyPro',
              fontWeight: FontWeight.w500, 
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ================= NEW LOGO (FULL IMAGE) =================
  Widget _buildPremiumLogo(double size) {
    return Container(
      width: size + 40,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4CC), Color(0xFFFFE082)],
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withOpacity(0.30),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: _goldBright, width: 1.5),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Image.asset(
          'assets/icon/MOI-EES (IOS).png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ================= GOLD BUTTON =================
  Widget _buildRegisterButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF4D46A),
            Color(0xFFDFB73B),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withOpacity(0.35),
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
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'ចូលប្រើប្រាស់',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'KantumruyPro',
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= FOOTER =================
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.20),
              Colors.white.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _gold.withOpacity(0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _gold.withOpacity(0.20),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_goldBright, _gold],
                ),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'General Department of Digital Technology and Media',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _goldDeep,
                  fontSize: 13.5,
                  fontFamily: 'KantumruyPro',
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}