import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dotenv/dotenv.dart';

/// ===============================================================
/// AuthService - Serviço de autenticação anônima do LeakGuard
///
/// Função principal:
/// - Autenticar o sistema no Firebase Auth utilizando requisição REST.
/// - Obter um `idToken` temporário usado para autorizar leituras
///   e escritas no Firebase Realtime Database.
///
/// Observação:
/// O token expira após um período, e deve ser renovado ao reiniciar
/// o console. A API Key é obtida a partir do arquivo `.env`.
/// ===============================================================
class AuthService {
  final DotEnv dotenv;

  AuthService(this.dotenv);

  // === 1. Retorna a API Key do Firebase lida do arquivo .env ===
  String get apiKey => dotenv['FIREBASE_API_KEY'] ?? '';

  // === 2. Realiza autenticação anônima no Firebase ===
  //
  // Faz uma requisição POST ao endpoint:
  //   https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}
  //
  // Retorna:
  // - idToken (String): Token JWT usado nas requisições REST do Realtime Database
  // - null: Caso a autenticação falhe
  Future<String?> autenticarAnonimamente() async {
    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}), // corpo vazio → login anônimo
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['idToken'];
      } else {
        print('Erro na autenticação Firebase: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exceção durante autenticação: $e');
      return null;
    }
  }
}
