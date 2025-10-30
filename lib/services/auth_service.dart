import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dotenv/dotenv.dart';

/// Classe responsável por autenticar o sistema no Firebase.
/// Utiliza autenticação anônima, obtendo um idToken
/// para autorizar leituras no Realtime Database.
class AuthService {
  final DotEnv dotenv;

  AuthService(this.dotenv);

  /// Retorna a API Key do Firebase lida do `.env`
  String get apiKey => dotenv['FIREBASE_API_KEY'] ?? '';

  /// Realiza autenticação anônima com o Firebase Auth.
  /// Retorna o token (idToken) usado para autenticação nas requisições REST do Realtime Database.
  Future<String?> autenticarAnonimamente() async {
    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
    );
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({}), // corpo vazio = login anônimo
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['idToken']; // token de autenticação
    } else {
      print('Erro na autenticação: ${response.statusCode}');
      return null;
    }
  }
}
