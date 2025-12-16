import 'package:flutter/material.dart';
import 'user_service.dart'; // ✅ Import du service

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;
  
  // Instanciation du service pour gérer l'API
  final UserService _userService = UserService();

  // --- LOGIQUE MÉTIER ---
  Future<void> _souscrire() async {
    setState(() => _isLoading = true);

    // Appel réel au Backend
    bool succes = await _userService.souscrireAbonnement(1);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (succes) {
      _afficherSucces();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Échec de l'abonnement. Vérifiez votre connexion ou connectez-vous."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- UI ---
  void _afficherSucces() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 10),
            Text("Félicitations ! 🎉", textAlign: TextAlign.center),
          ],
        ),
        content: const Text(
          "Bienvenue dans le club Santé+.\n\n"
          "Vos prochaines livraisons seront GRATUITES et PRIORITAIRES.",
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop(); // Ferme le dialogue
                Navigator.of(ctx).pop(); // Retourne à l'accueil
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text("PROFITER DE MES AVANTAGES"),
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Offre Santé+", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: const BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.diamond, size: 60, color: Colors.amber),
                  SizedBox(height: 10),
                  Text(
                    "Devenez Membre\nSANTÉ +",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "La santé sans attendre, sans frais.",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // AVANTAGES
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildAdvantage(Icons.delivery_dining, "Livraison Gratuite", "Ne payez plus jamais vos frais de livraison."),
                  _buildAdvantage(Icons.flash_on, "Priorité Absolue", "Vos commandes passent avant tout le monde."),
                  _buildAdvantage(Icons.support_agent, "Support VIP", "Une ligne dédiée avec un pharmacien."),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // PRIX
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.deepPurple.shade100),
                borderRadius: BorderRadius.circular(20),
                color: Colors.deepPurple.shade50,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Abonnement Mensuel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("5 000 F", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple[800])),
                      const Text("/ mois", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // BOUTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _souscrire,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 25, width: 25,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("S'ABONNER MAINTENANT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvantage(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: Colors.deepPurple, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 5),
                Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.3)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
