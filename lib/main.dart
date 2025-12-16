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
import 'ads_banner.dart'; // ✅ AJOUT : Import de la bannière

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

  LatLng center = LatLng(5.3600, -4.0083);
  List<Marker> markers = [];

  @override
  void initState() {
    super.initState();
    _obtenirPositionEtCharger();
  }

  // --- CARTE & GPS ---
  Future<void> _obtenirPositionEtCharger() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _chargerPharmacies();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _chargerPharmacies();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _chargerPharmacies();
      return;
    }

    Position positionReelle = await Geolocator.getCurrentPosition();

    if (!mounted) return;

    setState(() {
      center = LatLng(positionReelle.latitude, positionReelle.longitude);
      mapController.move(center, 15.0);
    });

    _chargerPharmacies();
  }

  void _chargerPharmacies() async {
    if (!mounted) return;

    setState(() {
      markers = [
        Marker(
          point: center,
          width: 80,
          height: 80,
          child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
        ),
      ];
    });
  }

  // --- NAVIGATION ---
  void _lancerCommande(String nomMedicament) {
    if (nomMedicament.isEmpty) return;
    searchController.clear();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(medicamentNom: nomMedicament),
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text("Utilisateur"),
              accountEmail: Text("+225 07 07 ..."),
              currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white, child: Icon(Icons.person)),
              decoration: BoxDecoration(color: Colors.teal),
            ),
            ListTile(
              leading: const Icon(Icons.diamond, color: Colors.purple),
              title: const Text("Offre Santé+ (Premium)"),
              onTap: () {
                Navigator.pop(context); 
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SubscriptionScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text("Déconnexion"),
              onTap: () { },
            ),
          ],
        ),
      ),
      
      body: Stack(
        children: [
          // 1. Fond de carte
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
              MarkerLayer(markers: markers),
            ],
          ),

          // 2. Barre de recherche (Positioned Top 50)
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Card(
              elevation: 6,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                              hintText: AppStrings.searchHint,
                              border: InputBorder.none,
                              prefixIcon: IconButton(
                                icon: const Icon(Icons.menu, color: Colors.teal),
                                onPressed: () {
                                  _scaffoldKey.currentState?.openDrawer();
                                },
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.camera_alt,
                                    color: Colors.teal),
                                tooltip: "Scanner une ordonnance",
                                onPressed: _ouvrirScanner,
                              ),
                            ),
                          );
                        },
                        suggestionsCallback: (pattern) async {
                          return await api.rechercherMedicaments(pattern);
                        },
                        itemBuilder: (context, suggestion) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.shade50,
                              child: const Icon(Icons.medication,
                                  color: Colors.teal, size: 20),
                            ),
                            title: Text(suggestion.nom,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            trailing: Text(
                                suggestion.prix != null
                                    ? "${suggestion.prix} F"
                                    : "",
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)),
                          );
                        },
                        onSelected: (suggestion) {
                          searchController.text = suggestion.nom;
                          _lancerCommande(suggestion.nom);
                        },
                        emptyBuilder: (context) => const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Aucun médicament trouvé.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                        loadingBuilder: (context) => const SizedBox(
                          height: 60,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: Colors.teal)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. ✅ AJOUT : Bannière Publicitaire (Positioned Top 130)
          const Positioned(
            top: 130, 
            left: 0, 
            right: 0,
            child: AdsBanner(),
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        onPressed: _ouvrirScanner,
        child: const Icon(Icons.document_scanner, color: Colors.white),
      ),
    ); 
  } 
}
