import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ApiService {
  // ✅ Votre URL Backend (Render)
  static const String baseUrl = 'https://pharmaci-backend.onrender.com';

  static String? token; 
  static String? nomUtilisateur;

  // --- AUTHENTIFICATION ---

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
        token = data['access_token'];
        nomUtilisateur = data['nom'];
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  // --- CARTE & PHARMACIES ---

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

  // --- RECHERCHE INTELLIGENTE (LIVE) ---

  Future<List<Medicament>> rechercherMedicaments(String query) async {
    if (query.length < 2) return [];

    // ✅ VRAIE CONNEXION AU BACKEND NESTJS + MEILISEARCH
    final url = Uri.parse('$baseUrl/medicaments/recherche?q=$query');
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
         // Le backend renvoie : { "hits": [ ... ], ... } ou directement [ ... ] selon la config Meili
         // Avec votre code backend actuel, il renvoie directement un tableau
         final dynamic data = json.decode(response.body);
         
         // Gestion flexible (si Meili renvoie un objet wrapper ou une liste directe)
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
      print("Erreur recherche: $e");
      return [];
    }
  }

  // --- COMMANDES ---

  Future<String?> envoyerDemande(String nomMedicament, LatLng position, String modePaiement) async {
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
        }),
      );
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['id']; // Le backend doit renvoyer l'ID créé
      }
      return null;
    } catch (e) { return null; }
  }

  Future<Map<String, dynamic>?> verifierDemandeComplete(String id) async {
    final url = Uri.parse('$baseUrl/demandes/$id');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {}
    return null;
  }

  // --- ITINERAIRE ---
  
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

// --- MODÈLES DE DONNÉES MIS À JOUR ---

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
  final String nomCommercial; // Ex: DOLIPRANE
  final String dci;           // Ex: Paracétamol
  final String forme;         // Ex: Comprimé
  final String dosage;        // Ex: 1000mg
  final num? prix;            // Ex: 1500 (Peut être null)

  Medicament({
    required this.id, 
    required this.nomCommercial, 
    required this.dci, 
    required this.forme,
    required this.dosage,
    this.prix
  });
  
  // Getter pour compatibilité avec l'ancien code si besoin
  String get nom => "$nomCommercial $dosage"; 
  String get description => "$dci - $forme";

  factory Medicament.fromJson(Map<String, dynamic> json) {
    return Medicament(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0, 
      nomCommercial: json['nomCommercial'] ?? json['nom'] ?? 'Inconnu', // Fallback si ancien format
      dci: json['dci'] ?? '', 
      forme: json['forme'] ?? '',
      dosage: json['dosage'] ?? '',
      prix: json['prixReference'] // Le backend envoie 'prixReference'
    );
  }
}
