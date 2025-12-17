import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ✅ Votre URL Backend (Render)
  static const String baseUrl = 'https://pharmaci-backend.onrender.com';

  static String? token; 
  static String? nomUtilisateur;

  // ==========================================================
  // 💾 GESTION DU STOCKAGE LOCAL (Persistance)
  // ==========================================================

  // 1. Charger le token au démarrage de l'app (appelé dans main.dart)
  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');
    nomUtilisateur = prefs.getString('auth_nom');
  }

  // 2. Sauvegarder le token après connexion réussie
  static Future<void> _saveToken(String newToken, String newNom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', newToken);
    await prefs.setString('auth_nom', newNom);
    token = newToken;
    nomUtilisateur = newNom;
  }

  // 3. Déconnecter (Effacer le token)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_nom');
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
        
        // On sauvegarde pour la prochaine ouverture de l'app
        await _saveToken(data['access_token'], data['nom'] ?? 'Utilisateur');
        
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  // ==========================================================
  // 📍 CARTE & PHARMACIES
  // ==========================================================

  Future<List<Pharmacie>> trouverProches(LatLng position) async {
    final url = Uri.parse('$baseUrl/pharmacies/proche?lat=${position.latitude}&lon=${position.longitude}');
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
  // 🔍 RECHERCHE INTELLIGENTE (MeiliSearch via Backend)
  // ==========================================================

  Future<List<Medicament>> rechercherMedicaments(String query) async {
    if (query.length < 2) return [];

    final url = Uri.parse('$baseUrl/medicaments/recherche?q=$query');
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
         final dynamic data = json.decode(response.body);
         
         // Gestion flexible selon format de réponse (Tableau direct ou Objet { hits: [] })
         List<dynamic> listeHits = [];
         if (data is List) {
           listeHits = data;
         } else if (data['hits'] != null) {
           listeHits = data['hits'];
         }

         return listeHits.map((json) => Medicament.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ==========================================================
  // 📦 COMMANDES
  // ==========================================================

  Future<String?> envoyerDemande(String nomMedicament, LatLng position, String modePaiement) async {
    // Si le token a été perdu en mémoire, on tente de le recharger
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
          // Vous pouvez ajouter 'priorite': 'URGENT' ici si besoin via l'UI
        }),
      );
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['id'];
      }
      return null;
    } catch (e) { return null; }
  }

  Future<Map<String, dynamic>?> verifierDemandeComplete(String id) async {
    final url = Uri.parse('$baseUrl/demandes/$id');
    try {
      if (token == null) await loadToken();
      
      final response = await http.get(
        url,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {}
    return null;
  }

  // ==========================================================
  // 🛣️ ITINÉRAIRE (OSRM)
  // ==========================================================
  
  Future<List<LatLng>> getItineraire(LatLng depart, LatLng arrivee) async {
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/${depart.longitude},${depart.latitude};${arrivee.longitude},${arrivee.latitude}?overview=full&geometries=geojson'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coords = data['routes'][0]['geometry']['coordinates'];
        return coords.map((p) => LatLng(p[1].toDouble(), p[0].toDouble())).toList();
      }
    } catch (e) {}
    return [];
  }
}

// ==========================================================
// 🧩 MODÈLES DE DONNÉES (Synchronisés avec Backend)
// ==========================================================

class Pharmacie {
  final String id, nom;
  final LatLng position;
  Pharmacie({required this.id, required this.nom, required this.position});
  
  factory Pharmacie.fromJson(Map<String, dynamic> json) {
    // Gestion du GeoJSON ou coordonnées plates
    final coords = json['position'] != null && json['position']['coordinates'] != null 
        ? json['position']['coordinates'] 
        : [0.0, 0.0];
    return Pharmacie(
      id: json['id']?.toString() ?? '0', 
      nom: json['nom'] ?? 'Pharmacie Partenaire', 
      position: LatLng(coords[1], coords[0]) // Attention: GeoJSON est [Lon, Lat] -> LatLng est (Lat, Lon)
    );
  }
}

class Medicament {
  final int id;
  final String nomCommercial;
  final String dci;
  final String forme;
  final String dosage;
  final num? prix; // Peut être null

  Medicament({
    required this.id, 
    required this.nomCommercial, 
    required this.dci, 
    required this.forme,
    required this.dosage,
    this.prix
  });
  
  // Helpers pour l'affichage
  String get nom => "$nomCommercial $dosage"; 
  String get description => "$dci - $forme";

  factory Medicament.fromJson(Map<String, dynamic> json) {
    return Medicament(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0, 
      nomCommercial: json['nomCommercial'] ?? json['nom'] ?? 'Inconnu',
      dci: json['dci'] ?? '', 
      forme: json['forme'] ?? '',
      dosage: json['dosage'] ?? '',
      // Le backend envoie 'prixReference', on le mappe sur 'prix'
      prix: json['prixReference'] 
    );
  }
}
