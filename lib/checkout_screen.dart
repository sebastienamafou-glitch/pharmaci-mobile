import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart'; // ✅ Import nécessaire pour le GPS
import 'api_service.dart'; // ✅ Import pour récupérer le Token et l'URL

class CheckoutScreen extends StatefulWidget {
  final String medicamentNom;
  final LatLng positionClient; // ✅ On reçoit la vraie position GPS

  const CheckoutScreen({
    super.key, 
    required this.medicamentNom,
    required this.positionClient, // ✅ Requis pour la livraison
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _repereController = TextEditingController();
  
  bool _isUrgent = false;
  bool _isLoading = false;
  
  String _selectedPaymentMethod = 'ESPECES'; 

  Future<void> envoyerCommande() async {
    // 1. Validation locale
    if (_repereController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Merci d'ajouter un point de repère.")),
      );
      return;
    }

    // 2. Vérification de la connexion (Sécurité)
    if (ApiService.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur: Vous n'êtes pas connecté.")),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // 3. Construction de l'URL (Basée sur ApiService pour éviter les erreurs)
      final url = Uri.parse('${ApiService.baseUrl}/demandes');

      // 4. Envoi de la requête
      final response = await http.post(
        url,
        // ✅ CORRECTION CRITIQUE : Ajout du Token dans le Header
        headers: { 
          "Content-Type": "application/json",
          "Authorization": "Bearer ${ApiService.token}",
        },
        body: jsonEncode({
          "medicament": widget.medicamentNom,
          // ✅ CORRECTION CRITIQUE : Utilisation du vrai GPS
          "lat": widget.positionClient.latitude,
          "lon": widget.positionClient.longitude,
          "modePaiement": _selectedPaymentMethod,
          "pointDeRepere": _repereController.text,
          "priorite": _isUrgent ? "URGENT" : "STANDARD"
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _afficherSucces();
      } else {
        // Gestion des erreurs backend
        throw Exception("Erreur ${response.statusCode}: Impossible de commander.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _afficherSucces() {
    String messagePaiement = _selectedPaymentMethod == 'ESPECES' 
        ? "Préparez votre monnaie à la livraison."
        : "Une demande de débit ${_selectedPaymentMethod} vous sera envoyée.";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Commande Validée ! ✅"),
        content: Text(
            "Votre demande a été transmise au hub le plus proche.\n\n"
            "$messagePaiement\n\n"
            "Un livreur va vous être assigné."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); 
              Navigator.of(ctx).pop(); 
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String label, String id, Color color, IconData icon) {
    bool isSelected = _selectedPaymentMethod == id;
    return GestureDetector(
      onTap: () {
        setState(() { _selectedPaymentMethod = id; });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 30),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.bold,
              color: isSelected ? color : Colors.grey
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Paiement & Livraison"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Récapitulatif Médicament
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.medication, color: Colors.blue),
                  const SizedBox(width: 15),
                  Expanded(child: Text(widget.medicamentNom, style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            
            const SizedBox(height: 25),
            const Text("📍 Point de Repère", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _repereController,
              decoration: const InputDecoration(
                hintText: "Ex: Portail vert, face maquis...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
                filled: true,
              ),
            ),

            const SizedBox(height: 25),
            const Text("⚡ Urgence", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SwitchListTile(
              title: const Text("Livraison Express (+1500F)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              value: _isUrgent,
              activeColor: Colors.red,
              onChanged: (v) => setState(() => _isUrgent = v),
            ),

            const SizedBox(height: 25),
            
            // SECTION PAIEMENT
            const Text("💳 Moyen de Paiement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPaymentOption("Espèces", "ESPECES", Colors.green, Icons.money),
                _buildPaymentOption("Wave", "WAVE", Colors.blue, Icons.waves),
                _buildPaymentOption("Orange", "OM", Colors.orange, Icons.circle), 
                _buildPaymentOption("MTN", "MTN", Colors.yellow[800]!, Icons.network_cell),
              ],
            ),
            
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : envoyerCommande,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : Text("PAYER ${_selectedPaymentMethod == 'ESPECES' ? 'A LA LIVRAISON' : 'MAINTENANT'}", 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
