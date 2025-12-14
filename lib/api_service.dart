import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class ApiService {
  static const String baseUrl = 'https://pharmaci-backend.onrender.com';

  static String? token; 
  static String? nomUtilisateur;

  // ✅ Inscription avec Téléphone
  Future<bool> inscription(String nom, String telephone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/inscription'),
        headers: {'Content-Type': 'application/json'},
        // On envoie 'telephone'
        body: json.encode({'nom': nom, 'telephone': telephone, 'password': password}),
      );
      return response.statusCode == 201;
    } catch (e) { return false; }
  }

  // ✅ Connexion avec Téléphone
  Future<bool> connexion(String telephone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        // On envoie 'telephone'
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

  // ... (Le reste du fichier reste identique, je remets juste les méthodes de base pour que le fichier soit complet)
  
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

  Future<List<Medicament>> rechercherMedicaments(String query) async {
    if (query.length < 2) return [];
    final url = Uri.parse('$baseUrl/medicaments/recherche?q=$query');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> hits = data['hits'];
        return hits.map((json) => Medicament.fromJson(json)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  Future<String?> envoyerDemande(String nomMedicament, LatLng position, String modePaiement) async {
    final url = Uri.parse('$baseUrl/demandes');
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

class Pharmacie {
  final String id, nom;
  final LatLng position;
  Pharmacie({required this.id, required this.nom, required this.position});
  factory Pharmacie.fromJson(Map<String, dynamic> json) {
    final coords = json['position'] != null && json['position']['coordinates'] != null 
        ? json['position']['coordinates'] 
        : [0.0, 0.0];
    return Pharmacie(id: json['id'] ?? '0', nom: json['nom'] ?? 'Inconnu', position: LatLng(coords[1], coords[0]));
  }
}

class Medicament {
  final int id;
  final String nom, description, forme;
  Medicament({required this.id, required this.nom, required this.description, required this.forme});
  factory Medicament.fromJson(Map<String, dynamic> json) {
    return Medicament(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()), 
      nom: json['nom'] ?? '', 
      description: json['description'] ?? '', 
      forme: json['forme'] ?? ''
    );
  }
}
