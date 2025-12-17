import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("À propos")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Logo de l'application (PharmaCi)
            Image.asset('assets/images/logo.png', height: 80),
            const Text("PharmaCi v1.0.0", style: TextStyle(fontWeight: FontWeight.bold)),
            
            const Divider(height: 60),
            
            const Text("DÉVELOPPÉ PAR", style: TextStyle(fontSize: 12, color: Colors.grey, letterSpacing: 2)),
            const SizedBox(height: 15),
            
            // Logo de votre entreprise (WebappCi)
            Image.asset('assets/images/logo_webappci.png', height: 60),
            const SizedBox(height: 20),
            
            const Text(
              "WebappCi est une agence digitale spécialisée dans le développement de solutions innovantes en Côte d'Ivoire.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            
            const SizedBox(height: 30),
            
            ListTile(
              leading: const Icon(Icons.language, color: Colors.blue),
              title: const Text("Visiter notre site web"),
              onTap: () => launchUrl(Uri.parse('https://votre-site-webappci.com')),
            ),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.red),
              title: const Text("Nous contacter"),
              onTap: () => launchUrl(Uri.parse('mailto:contact@webappci.com')),
            ),
          ],
        ),
      ),
    );
  }
}
