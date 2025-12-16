import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdsBanner extends StatefulWidget {
  const AdsBanner({Key? key}) : super(key: key);

  @override
  State<AdsBanner> createState() => _AdsBannerState();
}

class _AdsBannerState extends State<AdsBanner> {
  List<dynamic> _pubs = [];
  bool _isLoading = true;

  // ⚠️ URL Render
  final String apiUrl = "https://pharmaci-backend.onrender.com/publicites";

  @override
  void initState() {
    super.initState();
    _fetchPubs();
  }

  Future<void> _fetchPubs() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          _pubs = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur Pubs: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink(); // Rien si chargement
    if (_pubs.isEmpty) return const SizedBox.shrink(); // Rien si pas de pub

    return CarouselSlider(
      options: CarouselOptions(
        height: 140.0, // Hauteur de la bannière
        autoPlay: true, // Défilement auto
        autoPlayInterval: const Duration(seconds: 5),
        enlargeCenterPage: true,
        viewportFraction: 0.9,
        aspectRatio: 16/9,
      ),
      items: _pubs.map((pub) {
        return Builder(
          builder: (BuildContext context) {
            return Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: 5.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 3))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image de fond
                    CachedNetworkImage(
                      imageUrl: pub['imageUrl'] ?? "",
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[300]),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                    // Dégradé pour lisibilité texte
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        ),
                      ),
                    ),
                    // Titre / Label "Sponsorisé"
                    Positioned(
                      bottom: 10,
                      left: 15,
                      right: 15,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                            child: const Text("SPONSORISÉ", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pub['titre'] ?? "",
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}
