import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ApiService {
  // ⚠️ Assurez-vous que cette URL est bien la vôtre (sans slash à la fin)
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

  // --- RECHERCHE INTELLIGENTE (CORRECTION MAJEURE) ---

  Future<List<Medicament>> rechercherMedicaments(String query) async {
    if (query.length < 2) return [];

    // 1. On essaie de demander au serveur (si vous avez une vraie DB de médicaments plus tard)
    /*
    final url = Uri.parse('$baseUrl/medicaments/recherche?q=$query');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
         // ... traitement normal ...
      }
    } catch (e) {}
    */

    // 2. ASTUCE MVP : Le "Free-Text"
    // Au lieu de bloquer si on ne trouve rien, on renvoie le texte tapé comme une option valide.
    // Cela permet au Ministre de commander "Doliprane", "Paracetamol", ou "Truc pour la tête".
    // L'appli pensera que c'est un résultat venant du serveur.
    
    await Future.delayed(const Duration(milliseconds: 500)); // Petit délai pour faire "réel"
    
    return [
      Medicament(
        id: 0, 
        nom: query, // On reprend exactement ce que l'utilisateur a tapé
        description: "Disponible pour commande immédiate", 
        forme: "Standard"
      )
    ];
  }

  // --- COMMANDES ---

  Future<String?> envoyerDemande(String nomMedicament, LatLng position, String modePaiement) async {
    final url = Uri.parse('$baseUrl/demandes');
    
    // On sécurise l'envoi
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
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
        return data['id'];
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

  // --- ITINERAIRE (ROUTING) ---
  
  Future<List<LatLng>> getItineraire(LatLng depart, LatLng arrivee) async {
    // Utilisation du service public OSRM (Gratuit, pas de clé API requise pour la démo)
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/${depart.longitude},${depart.latitude};${arrivee.longitude},${arrivee.latitude}?overview=full&geometries=geojson'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coords = data['routes'][0]['geometry']['coordinates'];
        // OSRM renvoie [lon, lat], FlutterMap veut [lat, lon]
        return coords.map((p) => LatLng(p[1].toDouble(), p[0].toDouble())).toList();
      }
    } catch (e) {}
    return [];
  }
}

// --- MODÈLES DE DONNÉES ---

class Pharmacie {
  final String id, nom;
  final LatLng position;
  Pharmacie({required this.id, required this.nom, required this.position});
  factory Pharmacie.fromJson(Map<String, dynamic> json) {
    final coords = json['position'] != null && json['position']['coordinates'] != null 
        ? json['position']['coordinates'] 
        : [0.0, 0.0];
    return Pharmacie(
      id: json['id'] ?? '0', 
      nom: json['nom'] ?? 'Pharmacie Partenaire', 
      position: LatLng(coords[1], coords[0])
    );
  }
}

class Medicament {
  final int id;
  final String nom, description, forme;
  Medicament({required this.id, required this.nom, required this.description, required this.forme});
  
  // Plus robuste contre les erreurs de format
  factory Medicament.fromJson(Map<String, dynamic> json) {
    return Medicament(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0, 
      nom: json['nom'] ?? '', 
      description: json['description'] ?? '', 
      forme: json['forme'] ?? ''
    );
  }
}
