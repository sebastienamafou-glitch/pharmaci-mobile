import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'strings.dart'; // Conservé même si non utilisé dans cette version du design

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  
  @override
  void initState() {
    super.initState();
    _initialiserApp();
  }

  void _initialiserApp() async {
    // 1. Simulation de vérification (Connexion, GPS, Token...)
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // 2. Navigation vers l'écran d'auth
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal, // Couleur de fond conservée
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ VOTRE NOUVEAU LOGO ICI
            SizedBox(
              height: 150, // Ajustez la taille ici si besoin
              child: Image.asset(
                'assets/images/logo_webappci.png',
                fit: BoxFit.contain,
              ),
            ),
            
            const SizedBox(height: 30), // Espace entre le logo et le chargement
            
            // Le cercle de chargement
            const CircularProgressIndicator(
              color: Colors.green, // Ou la couleur principale de votre app
            ),
          ],
        ),
      ),
    );
  }
}
