import 'dart:convert';
import 'package:flutter/material.dart'; // Ajouté pour le BuildContext et la navigation
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart'; // Import nécessaire pour la redirection automatique

class ApiService {
  static const String baseUrl = 'https://pharmaci-backend.onrender.com';

  static String? token; 
  static String? nomUtilisateur;

  static const String _keyToken = 'token';
  static const String _keyNom = 'nom';

  // ==========================================================
  // 🔐 GESTION DE LA SÉCURITÉ & INTERCEPTION
  // ==========================================================

  /// Prépare les en-têtes pour chaque requête
  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Vérifie si la réponse du serveur indique une session expirée (401)
  static void verifierReponse(http.Response response, BuildContext context) {
    if (response.statusCode == 401) {
      logout(); // Efface les données locales
      
      // Redirige l'utilisateur vers la page de connexion et vide l'historique
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Votre session a expiré. Veuillez vous reconnecter.")),
      );
    }
  }

  // ==========================================================
  // 💾 STOCKAGE LOCAL
  // ==========================================================

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_keyToken);
    nomUtilisateur = prefs.getString(_keyNom);
  }

  static Future<void> _saveToken(String newToken, String newNom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, newToken);
    await prefs.setString(_keyNom, newNom);
    token = newToken;
    nomUtilisateur = newNom;
  }

  static Future<bool> estConnecte() async {
    if (token != null) return true;
    await loadToken();
    return token != null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyNom);
    token = null;
    nomUtilisateur = null;
  }
  
  // ==========================================================
  // 🔑 AUTHENTIFICATION
  // ==========================================================

  Future<bool> inscription(String nom, String telephone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/inscription'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'nom': nom, 'telephone': telephone, 'password': password}),
      );
      return response.statusCode == 201;
    } catch (e) { return false; }
  }

  Future<bool> connexion(String telephone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'telephone': telephone, 'password': password}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveToken(data['access_token'], data['nom'] ?? 'Utilisateur');
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  // ==========================================================
  // 🔍 RECHERCHE & PHARMACIES (Requiert BuildContext pour la sécurité)
  // ==========================================================

  Future<List<Medicament>> rechercherMedicaments(String query, BuildContext context) async {
    if (query.length < 2) return [];

    final url = Uri.parse('$baseUrl/medicaments/recherche?q=$query');
    
    try {
      final response = await http.get(url, headers: _getHeaders());
      
      // ✅ Intercepteur : vérifie si le token est encore valide
      verifierReponse(response, context);

      if (response.statusCode == 200) {
         final dynamic data = json.decode(response.body);
         List<dynamic> listeHits = (data is List) ? data : (data['hits'] ?? []);
         return listeHits.map((json) => Medicament.fromJson(json)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  Future<List<Pharmacie>> trouverProches(LatLng position, BuildContext context, {int rayon = 5000}) async {
    final url = Uri.parse('$baseUrl/pharmacies/proche?lat=${position.latitude}&lon=${position.longitude}&rayon=$rayon');
    try {
      final response = await http.get(url, headers: _getHeaders());
      verifierReponse(response, context);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Pharmacie.fromJson(json)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  // ==========================================================
  // 📦 COMMANDES
  // ==========================================================

  Future<String?> envoyerDemande(
    BuildContext context,
    String nomMedicament, 
    LatLng position, 
    String modePaiement,
    { String? pointDeRepere, String priorite = 'STANDARD' } 
  ) async {
    
    if (token == null) await loadToken();

    final url = Uri.parse('$baseUrl/demandes');
    
    try {
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: json.encode({
          'medicament': nomMedicament,
          'lat': position.latitude,
          'lon': position.longitude,
          'modePaiement': modePaiement,
          'pointDeRepere': pointDeRepere ?? '',
          'priorite': priorite,
        }),
      );
      
      verifierReponse(response, context);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['id'];
      }
      return null;
    } catch (e) { return null; }
  }
}

// ==========================================================
// 🧩 MODÈLES DE DONNÉES
// ==========================================================

class Pharmacie {
  final String id, nom;
  final LatLng position;
  Pharmacie({required this.id, required this.nom, required this.position});
  
  factory Pharmacie.fromJson(Map<String, dynamic> json) {
    final coords = json['position'] != null && json['position']['coordinates'] != null 
        ? json['position']['coordinates'] 
        : [0.0, 0.0];
    return Pharmacie(
      id: json['id']?.toString() ?? '0', 
      nom: json['nom'] ?? 'Pharmacie Partenaire', 
      position: LatLng(coords[1], coords[0]) 
    );
  }
}

class Medicament {
  final int id;
  final String nomCommercial;
  final String dci;
  final String forme;
  final String dosage;
  final num? prix; 

  Medicament({
    required this.id, 
    required this.nomCommercial, 
    required this.dci, 
    required this.forme,
    required this.dosage,
    this.prix
  });
  
  String get nom => "$nomCommercial $dosage"; 
  String get description => "$dci - $forme";

  factory Medicament.fromJson(Map<String, dynamic> json) {
    return Medicament(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0, 
      nomCommercial: json['nomCommercial'] ?? json['nom'] ?? 'Inconnu',
      dci: json['dci'] ?? '', 
      forme: json['forme'] ?? '',
      dosage: json['dosage'] ?? '',
      prix: json['prixReference'] 
    );
  }
}
