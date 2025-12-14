import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Nécessaire pour inputFormatters
import 'api_service.dart';
import 'main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final ApiService api = ApiService();
  bool isLogin = true;
  
  // ✅ CHANGEMENT : Variable renommée pour plus de clarté
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  
  bool loading = false;

  void soumettre() async {
    // Validation simple
    if (_phoneCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs"), backgroundColor: Colors.orange),
      );
      return;
    }

    if (!isLogin && _nomCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le nom est obligatoire"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => loading = true);
    bool succes = false;

    // Appel API avec le téléphone
    if (isLogin) {
      succes = await api.connexion(_phoneCtrl.text.trim(), _passCtrl.text.trim());
    } else {
      succes = await api.inscription(_nomCtrl.text.trim(), _phoneCtrl.text.trim(), _passCtrl.text.trim());
      if (succes) {
        // Auto-login après inscription
        succes = await api.connexion(_phoneCtrl.text.trim(), _passCtrl.text.trim());
      }
    }

    if (!mounted) return;
    setState(() => loading = false);

    if (succes) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isLogin ? "Numéro ou mot de passe incorrect" : "Ce numéro existe déjà"), 
          backgroundColor: Colors.red
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60), // Espace en haut de l'écran

              // ✅ VOTRE NOUVEAU LOGO ICI
              Center(
                child: SizedBox(
                  height: 120, // Une taille un peu plus petite que sur le splash screen
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              
              const SizedBox(height: 40), // Espace avant le titre ou les champs

              Text(
                isLogin ? "Bon retour !" : "Créer un compte",
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00BFA6)),
              ),
              const SizedBox(height: 10),
              Text(
                isLogin ? "Connectez-vous avec votre numéro" : "Rejoignez la communauté PharmaCi",
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              if (!isLogin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: TextField(
                    controller: _nomCtrl,
                    decoration: _inputDecoration("Nom complet", Icons.person),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              
              // ✅ CHANGEMENT : Champ dédié au Téléphone
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone, // Clavier numérique
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))], // Chiffres et + uniquement
                decoration: _inputDecoration("Numéro de téléphone (ex: 0707...)", Icons.phone),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 15),
              
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: _inputDecoration("Mot de passe", Icons.lock),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => soumettre(),
              ),
              const SizedBox(height: 30),

              loading 
                ? const CircularProgressIndicator(color: Color(0xFF00BFA6))
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: soumettre,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFA6),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 5,
                      ),
                      child: Text(
                        isLogin ? "SE CONNECTER" : "S'INSCRIRE", 
                        style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
              
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                    _phoneCtrl.clear();
                    _passCtrl.clear();
                    _nomCtrl.clear();
                  });
                },
                child: Text(
                  isLogin ? "Pas de compte ? Inscrivez-vous" : "Déjà un compte ? Connectez-vous",
                  style: const TextStyle(color: Color(0xFF00BFA6), fontWeight: FontWeight.w600),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF00BFA6)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00BFA6), width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}
