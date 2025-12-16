import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  // ⚠️ Assurez-vous que cette URL est correcte (pour Android Emulator utilisez 10.0.2.2 si local)
  final String baseUrl = "https://pharmaci-backend.onrender.com/users";

  // Récupérer le token stocké (si vous avez implémenté le stockage lors du login)
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // S'abonner
  Future<bool> souscrireAbonnement(int dureeMois) async {
    final token = await _getToken();
    if (token == null) return false; // Pas connecté

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/subscribe'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Indispensable pour le Guard NestJS
        },
        body: jsonEncode({'dureeMois': dureeMois}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        print("Erreur abonnement: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Erreur réseau: $e");
      return false;
    }
  }

  // Récupérer le profil (pour voir si on est déjà Premium)
  Future<Map<String, dynamic>?> getProfil() async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
