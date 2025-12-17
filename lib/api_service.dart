import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ✅ Remplacez par votre URL (si émulateur Android: 'http://10.0.2.2:3000')
  static const String baseUrl = 'https://pharmaci-backend.onrender.com';

  static String? token; 
  static String? nomUtilisateur;

  // Clés de stockage
  static const String _keyToken = 'token';
  static const String _keyNom = 'nom';

  // ==========================================================
  // 💾 GESTION DU STOCKAGE LOCAL (Persistance)
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
  // 🔐 AUTHENTIFICATION
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
  // 📍 CARTE & PHARMACIES
  // ==========================================================

  Future<List<Pharmacie>> trouverProches(LatLng position, {int rayon = 5000}) async {
    final url = Uri.parse('$baseUrl/pharmacies/proche?lat=${position.latitude}&lon=${position.longitude}&rayon=$rayon');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Pharmacie.fromJson(json)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  // ==========================================================
  // 🔍 RECHERCHE INTELLIGENTE
  // ==========================================================

  Future<List<Medicament>> rechercherMedicaments(String query) async {
    if (query.length < 2) return [];

    final url = Uri.parse('$baseUrl/medicaments/recherche?q=$query');
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
         final dynamic data = json.decode(response.body);
         
         List<dynamic> listeHits = [];
         if (data is List) {
           listeHits = data;
         } else if (data['hits'] != null) {
           listeHits = data['hits'];
         }

         return listeHits.map((json) => Medicament.fromJson(json)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  // ==========================================================
  // 📦 COMMANDES
  // ==========================================================

  // ✅ CORRECTION : Utilisation de paramètres nommés {} pour éviter les confusions
  Future<String?> envoyerDemande(
    String nomMedicament, 
    LatLng position, 
    String modePaiement,
    { String? pointDeRepere, String priorite = 'STANDARD' } 
  ) async {
    
    if (token == null) await loadToken();

    final url = Uri.parse('$baseUrl/demandes');
    
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({
          'medicament': nomMedicament,
          'lat': position.latitude,
          'lon': position.longitude,
          'modePaiement': modePaiement,
          'pointDeRepere': pointDeRepere ?? '',
          'priorite': priorite,
        }),
      );
      
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
