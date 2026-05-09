import 'package:flutter/material.dart';
import 'package:gov_reg/routes/approute.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  // 🎨 NEW COLORS (from your screenshot)
  static const Color _bgTop = Color(0xFF0F2A6D);
  static const Color _bgMid = Color(0xFF1B3A8A);
  static const Color _bgBottom = Color(0xFF25479B);

  static const Color _blue = Color(0xFF3B82F6);
  static const Color _blueLight = Color(0xFF60A5FA);
  static const Color _gold = Color(0xFFE7C14D);
  static const Color _goldDark = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700 || size.width < 360;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _bgTop,
                _bgMid,
                _bgBottom,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
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
      ),
    );
  }
  Widget _buildBackgroundDecoration() {
    return Stack(
      children: [
        Positioned(
          top: -60,
          left: -40,
          child: _circle(180, Colors.white.withOpacity(0.06)),
        ),
        Positioned(
          top: 80,
          right: -50,
          child: _circle(220, Colors.white.withOpacity(0.04)),
        ),
        Positioned(
          bottom: 120,
          left: -30,
          child: _circle(160, Colors.white.withOpacity(0.05)),
        ),
        Positioned(
          bottom: -70,
          right: -20,
          child: _circle(220, Colors.white.withOpacity(0.04)),
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
  Widget _buildHeroCard(bool isSmall) {
    final double logoSize = isSmall ? 120 : 140;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildPremiumLogo(logoSize),
          const SizedBox(height: 18),

          Text(
            'សូមស្វាគមន៍មកកាន់',
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmall ? 24 : 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'khmer moul light',
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'កម្មវិធី EES MOI',
            style: TextStyle(
              color: Colors.white,
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
                colors: [_blueLight, _blue],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),

          const SizedBox(height: 18),
        ],
      ),
    );
  }
  Widget _buildPremiumLogo(double size) {
  return Container(
    width: size + 70,
    height: size + 70,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      shape: BoxShape.circle, 
      gradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.95),
          Colors.white.withOpacity(0.85),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          blurRadius: 25,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: const Color(0xFF3B82F6).withOpacity(0.25), 
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: ClipOval(
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white.withOpacity(0.95),
        child: Image.asset(
          'assets/img/LOGO ROUND.png',
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
}
  Widget _buildRegisterButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            _gold,
            _goldDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withOpacity(0.4),
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
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'ចូលប្រើប្រាស់',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'KantumruyPro',
            color: Colors.black,
          ),
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
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.shield, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'General Department of Digital Technology and Media',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13.5,
                  fontFamily: 'KantumruyPro',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}