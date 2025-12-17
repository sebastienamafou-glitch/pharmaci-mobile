import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:url_launcher/url_launcher.dart'; // Pour la politique de confidentialité

// Importations locales
import 'api_service.dart';
import 'checkout_screen.dart'; 
import 'scanner_screen.dart';  
import 'strings.dart';
import 'subscription_screen.dart';
import 'ads_banner.dart';
import 'auth_screen.dart'; // Requis pour la redirection de déconnexion

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
      theme: ThemeData(
        primarySwatch: Colors.teal, 
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
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

  // --- LOGIQUE GPS CORRIGÉE (Supprime le warning deprecated) ---
  Future<void> _obtenirPositionEtCharger() async {
    bool serviceEnabled;
    LocationPermission permission;

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

    try {
      // ✅ Correction de 'desiredAccuracy' (LocationSettings)
      Position positionReelle = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted) return;

      setState(() {
        _isGpsActive = true;
        userPosition = LatLng(positionReelle.latitude, positionReelle.longitude);
        _updateMarker();
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

  // --- ACTIONS ---
  Future<void> _lancerPolitique() async {
    final Uri url = Uri.parse('https://pharmaci-backend.onrender.com/politique');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _afficherMessage("Impossible d'ouvrir la politique de confidentialité.");
    }
  }

  void _recentrerCarte() {
    if (_isGpsActive) {
      mapController.move(userPosition, 16.0);
    } else {
      _obtenirPositionEtCharger(); 
    }
  }

  void _lancerCommande(String nomMedicament) {
    if (nomMedicament.isEmpty) return;
    searchController.clear();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          medicamentNom: nomMedicament,
          positionClient: userPosition, 
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

  void _afficherMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- INTERFACE ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: userPosition,
              initialZoom: 13.0,
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
          Positioned(top: 50, left: 15, right: 15, child: _buildSearchBar()),
          const Positioned(top: 130, left: 0, right: 0, child: AdsBanner()),
          Positioned(
            bottom: 100, right: 20,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              onPressed: _recentrerCarte,
              child: Icon(Icons.my_location, color: _isGpsActive ? Colors.blue : Colors.grey),
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

  Widget _buildSearchBar() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: TypeAheadField<Medicament>(
          controller: searchController,
          builder: (context, controller, focusNode) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
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
          // ✅ CORRECTION : Ajout de 'context' pour correspondre à ApiService
          suggestionsCallback: (pattern) async {
            return await api.rechercherMedicaments(pattern, context);
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
            _lancerCommande(suggestion.nom);
          },
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(ApiService.nomUtilisateur ?? "PharmaCi Client"),
            accountEmail: const Text("Bienvenue"),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white, 
              child: Icon(Icons.person, color: Colors.teal)
            ),
            decoration: const BoxDecoration(color: Colors.teal),
          ),
          ListTile(
            leading: const Icon(Icons.diamond, color: Colors.purple),
            title: const Text("Offre Santé+ (Premium)"),
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: Colors.blueGrey),
            title: const Text("Politique de Confidentialité"),
            onTap: () {
              Navigator.pop(context);
              _lancerPolitique();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text("Déconnexion"),
            onTap: () async {
              await ApiService.logout(); // Nettoyage session
              if (!mounted) return;
              // Redirection vers AuthScreen
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const AuthScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
