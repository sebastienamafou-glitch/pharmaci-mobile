import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;

  // ⚠️ MODIFIEZ ICI : Mettez l'URL réelle de votre API NestJS
  // Si vous testez sur émulateur Android, utilisez 10.0.2.2 au lieu de localhost
  final String apiUrl = "https://pharmaci-backend.onrender.com/users/subscribe"; 

  // --- LOGIQUE MÉTIER INTÉGRÉE (MODULE API) ---
  Future<void> _souscrire() async {
    setState(() => _isLoading = true);

    try {
      // 1. Récupération du Token (Stocké lors du Login)
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); // Assurez-vous que la clé est bien 'token'

      if (token == null) {
        throw Exception("Vous n'êtes pas connecté. Veuillez vous reconnecter.");
      }

      // 2. Appel API Réel vers le Backend NestJS
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Envoi du token JWT
        },
        body: jsonEncode({
          'plan': 'SANTE_PLUS', // Donnée envoyée au backend
          'montant': 5000,
          'moyenPaiement': 'WAVE_CI' // Simulation
        }),
      );

      // 3. Traitement de la réponse
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Succès : On met à jour le profil localement si nécessaire
        await prefs.setBool('isPremium', true);
        _afficherSucces();
      } else {
        // Erreur serveur (ex: fonds insuffisants, token expiré)
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['message'] ?? "Erreur lors de l'abonnement");
      }

    } catch (e) {
      // Gestion des erreurs (Réseau, etc.)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Échec : ${e.toString().replaceAll('Exception: ', '')}"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- INTERFACE UTILISATEUR (MODULE UI) ---
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
            // HEADER DESIGN
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

            // LISTE DES AVANTAGES
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

            // CARTE DE PRIX
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

            // BOUTON D'ACTION
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

            const SizedBox(height: 20),
            const Text("Annulable à tout moment.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 30),
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
