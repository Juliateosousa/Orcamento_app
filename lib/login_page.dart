import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'home_page.dart';

// ✅ DOMÍNIO PERMITIDO
const String allowedDomain = "espartmoveis.com";

// ✅ (opcional) emails específicos permitidos
const List<String> allowedEmails = [
  "espartmoveis@espartmoveis.com",
  "projetos@espartmoveis.com",
  "juliateosousa@espartmoveis.com",
];

// 🔐 Regra: ou está na lista OU termina com @domínio
bool isAllowedEmail(String? email) {
  if (email == null) return false;
  final e = email.toLowerCase().trim();

  final allowedList =
      allowedEmails.map((x) => x.toLowerCase().trim()).toList();

  return allowedList.contains(e) || e.endsWith("@$allowedDomain");
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool loading = false;
  String? errorMessage;

  // ✅ Use o Desktop Client ID no macOS
  // Pegue em: Google Cloud Console → Credentials → OAuth client → Desktop app
  static const String macosDesktopClientId =
      "1065549726082-p7ueiqnjig7jpf27l6blffkltibip6bf.apps.googleusercontent.com";

  Future<void> signInWithGoogle() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    GoogleSignIn? googleSignIn; // pra poder dar signOut depois
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // ===== WEB =====
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');

        userCredential =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // ===== ANDROID / IOS / MACOS =====

        googleSignIn = GoogleSignIn(
          // ✅ macOS precisa do clientId do tipo "Desktop"
          clientId: Platform.isMacOS ? macosDesktopClientId : null,
          scopes: const ['email'],
        );

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          // usuário cancelou
          if (mounted) setState(() => loading = false);
          return;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCredential.user;
      final email = user?.email ?? "";

      // 🔐 DOMAIN CHECK
      if (!isAllowedEmail(email)) {
        // importante: logout do firebase + google
        await FirebaseAuth.instance.signOut();
        if (googleSignIn != null) {
          await googleSignIn.signOut();
        }

        setState(() {
          errorMessage =
              "Este email não tem permissão para acessar.\n"
              "Use um email que termine com @$allowedDomain\n"
              "ou um email permitido da lista.\n\n"
              "Email usado: $email";
        });

        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(user: user),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Erro ao entrar com Google: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Espart Moveis',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),

                if (errorMessage != null) ...[
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : signInWithGoogle,
                    icon: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      loading ? 'Entrando...' : 'Entrar com Google',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}