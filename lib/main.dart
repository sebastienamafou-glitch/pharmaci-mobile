import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // <--- Nouvel import ajouté

import 'api_service.dart';
import 'auth_screen.dart';
import 'scanner_screen.dart';
import 'splash_screen.dart';
import 'strings.dart';

void main() {
  runApp(const PharmaCiApp());
}

class PharmaCiApp extends StatelessWidget {
  const PharmaCiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService api = ApiService();
  final MapController mapController = MapController();
  final TextEditingController searchController = TextEditingController();

  // Position par défaut (Abidjan)
  LatLng center = LatLng(5.3600, -4.0083);
  List<Marker> markers = [];
  List<LatLng> routePoints = [];
  bool rechercheEnCours = false;

  @override
  void initState() {
    super.initState();
    // Au lieu de charger direct, on demande le GPS d'abord
    _obtenirPositionEtCharger();
  }

  // --- NOUVELLE MÉTHODE GÉOLOCALISATION ---
  Future<void> _obtenirPositionEtCharger() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Vérifie si le GPS est activé
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Si GPS éteint, on charge la position par défaut (Abidjan)
      _chargerPharmacies(); 
      return;
    }

    // Vérifie les permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _chargerPharmacies(); // Refusé ? On charge par défaut
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions définitivement refusées, on charge par défaut
      _chargerPharmacies();
      return;
    }

    // ✅ On a la vraie position !
    Position positionReelle = await Geolocator.getCurrentPosition();
    
    if (!mounted) return;

    setState(() {
      // On met à jour le centre de la carte
      center = LatLng(positionReelle.latitude, positionReelle.longitude);
      // On déplace la caméra de la carte
      mapController.move(center, 15.0);
    });

    // On cherche les pharmacies autour de cette NOUVELLE position
    _chargerPharmacies();
  }

  // --- MÉTHODE MISE À JOUR ---
  void _chargerPharmacies() async {
    // On utilise 'center' qui est soit Abidjan (défaut), soit le GPS (si trouvé)
    final pharmacies = await api.trouverProches(center);
    
    if (!mounted) return;
    
    setState(() {
      markers = pharmacies.map((p) {
        return Marker(
          point: p.position,
          width: 80,
          height: 80,
          child: const Icon(Icons.location_on, color: Colors.green, size: 40),
        );
      }).toList();
      
      // Ajout de notre position (Bleu)
      markers.add(
        Marker(
          point: center,
          width: 80,
          height: 80,
          child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
        ),
      );
    });
  }

  void _ouvrirScanner() async {
    final resultatTexte = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
    if (resultatTexte != null && resultatTexte is String) {
      setState(() { searchController.text = resultatTexte; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.scannerSnack)));
    }
  }

  void _lancerRecherche() async {
    if (searchController.text.length < 2) return;
    
    setState(() => rechercheEnCours = true);
    final resultats = await api.rechercherMedicaments(searchController.text);
    setState(() => rechercheEnCours = false);

    if (resultats.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.notFound)));
      return;
    }
    _afficherResultats(resultats);
  }

  void _afficherResultats(List<Medicament> meds) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return ListView.builder(
          itemCount: meds.length,
          itemBuilder: (ctx, i) {
            final med = meds[i];
            return ListTile(
              leading: const Icon(Icons.medication),
              title: Text(med.nom),
              subtitle: Text(med.forme),
              trailing: ElevatedButton(
                child: const Text(AppStrings.btnSelect),
                onPressed: () {
                  Navigator.pop(ctx);
                  _demanderModePaiement(med);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _demanderModePaiement(Medicament med) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.payTitle),
        content: const Text(AppStrings.payContent),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.card_membership),
            label: const Text(AppStrings.payInsurance),
            onPressed: () {
              Navigator.pop(ctx);
              _envoyerDemande(med, "ASSURANCE");
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.money),
            label: const Text(AppStrings.payCash),
            onPressed: () {
              Navigator.pop(ctx);
              _envoyerDemande(med, "ESPECES");
            },
          ),
        ],
      ),
    );
  }

  void _envoyerDemande(Medicament med, String modePaiement) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppStrings.searching} ($modePaiement)")));
    final idDemande = await api.envoyerDemande(med.nom, center, modePaiement);
    
    if (idDemande != null) {
        _ecouterReponse(idDemande);
    }
  }

  void _ecouterReponse(String idDemande) async {
    bool trouve = false;
    int essais = 0;
    
    while (!trouve && essais < 20) { 
      await Future.delayed(const Duration(seconds: 3));
      final demandeData = await api.verifierDemandeComplete(idDemande);
      
      if (demandeData != null && demandeData['statut'] == 'TROUVE') {
        trouve = true;
        
        final posPharmacieJson = demandeData['positionPharmacie'];
        
        if (posPharmacieJson != null) {
            LatLng posPharmacie = LatLng(
                double.parse(posPharmacieJson['lat'].toString()), 
                double.parse(posPharmacieJson['lon'].toString())
            );

            List<LatLng> route = await api.getItineraire(center, posPharmacie);

            if (!mounted) return;
            setState(() {
                routePoints = route;
                markers.add(Marker(
                    point: posPharmacie,
                    width: 80,
                    height: 80,
                    child: const Column(
                        children: [
                            Icon(Icons.check_circle, color: Colors.redAccent, size: 40),
                            Text("ICI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))
                        ],
                    )
                ));
            });

            mapController.move(center, 13.5);

            showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => AlertDialog(
                    title: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 10),
                        const Expanded(child: Text("C'est trouvé !", style: TextStyle(fontSize: 18))),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("La ${demandeData['pharmacieNom']} a validé votre demande."),
                        const SizedBox(height: 20),
                        
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200)
                          ),
                          child: Column(
                            children: [
                              const Text("CODE DE RETRAIT", style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Text(
                                demandeData['codeRetrait'] ?? '----',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 5, color: Colors.black87),
                              ),
                              const SizedBox(height: 5),
                              const Text("À donner au livreur ou au pharmacien", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text("Mode de paiement :", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(demandeData['modePaiement'] ?? 'Non spécifié', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    actions: [
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text("Copier mandat Livreur"),
                        onPressed: () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                             content: Text("Code copié ! Envoyez-le à votre livreur."),
                             backgroundColor: Colors.green,
                             duration: Duration(seconds: 2),
                           ));
                        },
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(context), 
                        child: const Text("VOIR CARTE")
                      ),
                    ],
                ),
            );
        }
      }
      essais++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pharmaci.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    strokeWidth: 5.0,
                    color: Colors.blueAccent,
                  ),
                ],
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            top: 50, left: 15, right: 15,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: AppStrings.searchHint,
                          border: InputBorder.none,
                          suffixIcon: kIsWeb 
                              ? null 
                              : IconButton(
                                  icon: const Icon(Icons.camera_alt, color: Colors.teal),
                                  onPressed: _ouvrirScanner,
                                ),
                        ),
                      ),
                    ),
                    rechercheEnCours 
                      ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.search, color: Colors.teal),
                          onPressed: _lancerRecherche,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.logout, color: Colors.white),
        onPressed: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
        },
      ),
    );
  }
}
