import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'strings.dart'; // On utilise nos textes centralisés

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
    // Dans une V2, on vérifierait ici si le token est encore valide pour auto-login
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
      backgroundColor: Colors.teal, // Couleur de la marque
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LE LOGO (Assurez-vous d'avoir fait l'étape 1)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
              ),
              child: Image.asset(
                'assets/images/logo.png', 
                height: 100, 
                width: 100,
                errorBuilder: (c, o, s) => const Icon(Icons.local_pharmacy, size: 80, color: Colors.teal),
              ),
            ),
            const SizedBox(height: 20),
            
            // NOM DE L'APP
            const Text(
              AppStrings.appName,
              style: TextStyle(
                fontSize: 32, 
                fontWeight: FontWeight.bold, 
                color: Colors.white,
                letterSpacing: 2
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              AppStrings.slogan,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            
            const SizedBox(height: 50),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
