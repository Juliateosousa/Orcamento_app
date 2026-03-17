import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'itens_page.dart';
import 'clientes_page.dart';

class HomePage extends StatelessWidget {
  final User? user;

  const HomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Espart Moveis"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // center vertically
          children: [
            menuButton(
              context,
              label: "Clientes",
              icon: Icons.people,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClientesPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            menuButton(
              context,
              label: "Itens",
              icon: Icons.inventory,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ItensPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget menuButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          textStyle: const TextStyle(fontSize: 20),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      ),
    );
  }
}