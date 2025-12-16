import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

// Nos écrans et services
import 'api_service.dart';
import 'checkout_screen.dart'; // ✅ Écran de commande
import 'scanner_screen.dart';  // ✅ Écran Scanner
import 'strings.dart';

// Si vous avez un fichier séparé pour SubscriptionScreen, décommentez l'import ci-dessous
// et supprimez la classe dummy "SubscriptionScreen" tout en bas de ce fichier.
// import 'subscription_screen.dart'; 

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

  // Pour contrôler l'ouverture du Drawer manuellement
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Position par défaut (Abidjan)
  LatLng center = LatLng(5.3600, -4.0083);
  List<Marker> markers = [];

  @override
  void initState() {
    super.initState();
    _obtenirPositionEtCharger();
  }

  // ------------------------------------------------------------------------
  // 📍 GESTION DE LA CARTE ET LOCALISATION
  // ------------------------------------------------------------------------

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
      // Ajout de ma position (Bleu)
      markers = [
        Marker(
          point: center,
          width: 80,
          height: 80,
          child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
        ),
      ];
      // Ici, on pourrait ajouter les marqueurs des pharmacies (Vert)
    });
  }

  // ------------------------------------------------------------------------
  // 🚀 NAVIGATION
  // ------------------------------------------------------------------------

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

  // ------------------------------------------------------------------------
  // 📱 INTERFACE UTILISATEUR
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, // Clé nécessaire pour ouvrir le drawer via le bouton
      // ✅ MENU LATÉRAL (DRAWER)
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
                Navigator.pop(context); // Fermer le drawer
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
              onTap: () {
                // Logique de déconnexion
              },
            ),
          ],
        ),
      ),
      
      // ✅ CORPS DE LA PAGE (Stack : Carte + Barre de recherche)
      body: Stack(
        children: [
          // 1. LA CARTE
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

          // 2. BARRE DE RECHERCHE FLOTTANTE
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
                              
                              // ✅ BOUTON MENU (Ouvre le Drawer)
                              prefixIcon: IconButton(
                                icon: const Icon(Icons.menu, color: Colors.teal),
                                onPressed: () {
                                  _scaffoldKey.currentState?.openDrawer();
                                },
                              ),

                              // ✅ BOUTON SCANNER
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
        ],
      ),
      
      // Bouton Flottant (Raccourci Scanner)
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.document_scanner, color: Colors.white),
        onPressed: _ouvrirScanner,
      ),
    );
  }
}

// ------------------------------------------------------------------------
// 🛠️ CLASSE TEMPORAIRE (Si SubscriptionScreen n'existe pas encore)
// ------------------------------------------------------------------------
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Offre Santé+")),
      body: const Center(child: Text("Page d'abonnement en construction")),
    );
  }
}
