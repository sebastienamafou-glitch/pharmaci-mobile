import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // Outils pour la caméra et l'IA
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  
  bool _scanning = false;
  String _texteExtrait = "";

  @override
  void dispose() {
    _textRecognizer.close(); // Important de fermer l'IA quand on quitte
    super.dispose();
  }

  // Fonction principale : Photo -> Texte
  Future<void> _scannerOrdonnance() async {
    try {
      setState(() => _scanning = true);

      // 1. On ouvre la caméra
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      
      if (photo == null) {
        // L'utilisateur a annulé la prise de photo
        if (!mounted) return; // Sécurité
        setState(() => _scanning = false);
        return; 
      }

      // 2. On donne l'image à l'IA Google
      final inputImage = InputImage.fromFilePath(photo.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // --- CORRECTION MAJEURE ICI ---
      // On vérifie si l'écran est toujours affiché avant de toucher à l'interface
      if (!mounted) return; 

      // 3. On récupère le texte brut
      setState(() {
        _texteExtrait = recognizedText.text;
        _scanning = false;
      });

    } catch (e) {
      // En cas d'erreur
      if (!mounted) return; // Sécurité
      setState(() => _scanning = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lecture: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scanner Ordonnance")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Zone d'explication
            const Icon(Icons.document_scanner, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            const Text(
              "Prenez une photo nette de l'ordonnance.\nL'IA va extraire les noms des médicaments.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // Bouton Scanner
            _scanning
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _scannerOrdonnance,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("PRENDRE PHOTO"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(15),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),

            const SizedBox(height: 30),
            
            // Résultat
            if (_texteExtrait.isNotEmpty) ...[
              const Text("Texte détecté :", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(child: Text(_texteExtrait)),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  // ✅ On renvoie le texte trouvé à la page précédente (HomePage)
                  Navigator.pop(context, _texteExtrait);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text("UTILISER CE TEXTE", style: TextStyle(color: Colors.white)),
              )
            ]
          ],
        ),
      ),
    );
  }
}
