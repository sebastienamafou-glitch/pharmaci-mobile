import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

// Nos écrans et services
import 'api_service.dart';
import 'checkout_screen.dart'; 
import 'scanner_screen.dart';  
import 'strings.dart';
import 'subscription_screen.dart';
import 'ads_banner.dart';

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
      home: const HomePage(),
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

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Position par défaut (Abidjan)
  LatLng userPosition = LatLng(5.345317, -4.024429);
  bool _isGpsActive = false;
  List<Marker> markers = [];

  @override
  void initState() {
    super.initState();
    _obtenirPositionEtCharger();
  }

  // --- 1. GESTION ROBUSTE DU GPS ---
  Future<void> _obtenirPositionEtCharger() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Vérifie si le GPS est allumé
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _afficherMessage("Veuillez activer le GPS pour la livraison.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _afficherMessage("La permission GPS est requise.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _afficherMessage("GPS refusé définitivement. Allez dans les paramètres.");
      return;
    }

    // On récupère la position précise
    try {
      Position positionReelle = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high // Précision maximale pour la livraison
      );

      if (!mounted) return;

      setState(() {
        _isGpsActive = true;
        userPosition = LatLng(positionReelle.latitude, positionReelle.longitude);
        _updateMarker();
        // On bouge la caméra sur l'utilisateur
        mapController.move(userPosition, 15.0);
      });
    } catch (e) {
      debugPrint("Erreur GPS: $e");
    }
  }

  void _updateMarker() {
    setState(() {
      markers = [
        Marker(
          point: userPosition,
          width: 80,
          height: 80,
          child: const Column(
            children: [
               Icon(Icons.location_on, color: Colors.red, size: 40),
               Text("Moi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
            ],
          ),
        ),
      ];
    });
  }

  void _recentrerCarte() {
    if (_isGpsActive) {
      mapController.move(userPosition, 16.0);
    } else {
      _obtenirPositionEtCharger(); // Réessaie d'activer le GPS
    }
  }

  void _afficherMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- 2. NAVIGATION ET PASSAGE DE DONNÉES ---
  void _lancerCommande(String nomMedicament) {
    if (nomMedicament.isEmpty) return;
    searchController.clear();
    
    // ✅ CRITIQUE : On passe la position GPS à l'écran suivant
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          medicamentNom: nomMedicament,
          positionClient: userPosition, // <--- C'est ici que tout se joue
        ),
      ),
    );
  }

  void _ouvrirScanner() async {
    final resultatTexte = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
    if (resultatTexte != null && resultatTexte is String && resultatTexte.length > 2) {
      _lancerCommande(resultatTexte);
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(), // Code extrait plus bas pour lisibilité
      
      body: Stack(
        children: [
          // 1. Fond de carte
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: userPosition,
              initialZoom: 13.0,
              // Empêche de trop dézoomer (expérience client)
              minZoom: 10.0, 
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pharmaci.app',
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // 2. Barre de recherche (Top 50)
          Positioned(
            top: 50, left: 15, right: 15,
            child: _buildSearchBar(),
          ),

          // 3. Bannière Pub (Top 130)
          const Positioned(
            top: 130, left: 0, right: 0,
            child: AdsBanner(),
          ),

          // 4. ✅ AJOUT : Bouton de Recentrage GPS (Bas Droite)
          Positioned(
            bottom: 100,
            right: 20,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              onPressed: _recentrerCarte,
              child: Icon(
                Icons.my_location, 
                color: _isGpsActive ? Colors.blue : Colors.grey
              ),
            ),
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: _ouvrirScanner,
        child: const Icon(Icons.document_scanner, color: Colors.white),
      ),
    ); 
  }

  // --- WIDGETS EXTRAITS (Pour garder le code propre) ---

  Widget _buildSearchBar() {
    return Card(
      elevation: 6,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: TypeAheadField<Medicament>(
                controller: searchController,
                builder: (context, controller, focusNode) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: false,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: "Rechercher (ex: Doliprane...)",
                      border: InputBorder.none,
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.menu, color: Colors.teal),
                        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                      suffixIcon: const Icon(Icons.search, color: Colors.grey),
                    ),
                  );
                },
                suggestionsCallback: (pattern) async {
                  return await api.rechercherMedicaments(pattern);
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(
                    leading: const Icon(Icons.medication, color: Colors.teal),
                    title: Text(suggestion.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(suggestion.description, style: const TextStyle(fontSize: 12)),
                    trailing: Text(suggestion.prix != null ? "${suggestion.prix} F" : "", 
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  );
                },
                onSelected: (suggestion) {
                  searchController.text = suggestion.nom;
                  _lancerCommande(suggestion.nom);
                },
                emptyBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aucun résultat.', style: TextStyle(color: Colors.grey)),
                ),
                loadingBuilder: (context) => const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator(color: Colors.teal)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text("PharmaCi Client"),
              accountEmail: Text("Bienvenue"),
              currentAccountPicture: CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.teal)),
              decoration: BoxDecoration(color: Colors.teal),
            ),
            ListTile(
              leading: const Icon(Icons.diamond, color: Colors.purple),
              title: const Text("Offre Santé+ (Premium)"),
              onTap: () {
                Navigator.pop(context); 
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text("Déconnexion"),
              onTap: () { 
                // Logique de déconnexion ici
              },
            ),
          ],
        ),
      );
  }
}
