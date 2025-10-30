import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dotenv/dotenv.dart';
import '../models/firebase_leitura.dart';

/// Serviço responsável por conectar ao Firebase Realtime Database e escutar alterações em tempo real usando HTTP Streaming.
/// Essa classe mantém uma conexão contínua com o Firebase.
/// Sempre que o ESP32 envia uma nova leitura, o Firebase notifica o Dart automaticamente, sem necessidade de GET manual.
class FirebaseStreamService {
  final String authToken;
  final DotEnv dotenv;

  FirebaseStreamService(this.authToken, this.dotenv);

  /// Retorna a URL base do Firebase Realtime Database, lida do `.env`
  String get baseUrl => dotenv['FIREBASE_BASE_URL'] ?? '';

  /// Lê o valor atual do nó especificado no Firebase
  /// Esse método faz um GET simples para obter o estado atual do sensor no momento da inicialização
  Future<FirebaseLeitura?> getCurrentSensorData({String path = '/mq2'}) async {
    final url = Uri.parse('$baseUrl$path.json?auth=$authToken');
    final response = await http.get(url);

    if (response.statusCode == 200 && response.body != 'null') {
      try {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return FirebaseLeitura.fromJson(data);
        }
      } catch (e) {
        print('Erro ao decodificar valor atual: $e');
      }
    }
    return null;
  }

  /// Escuta as alterações em tempo real no nó especificado.
  /// [path] é o caminho dentro do Firebase onde o ESP32 grava os dados.
  /// Retorna um Stream<FirebaseLeitura?> que emite um novo objeto toda vez que os dados mudam no Firebase.
  Stream<FirebaseLeitura?> listenToSensorData({String path = '/mq2'}) async* {
    final url = Uri.parse('$baseUrl$path.json?auth=$authToken');

    // Cria uma requisição GET que será mantida aberta pelo Firebase
    final request = http.Request('GET', url);
    final client = http.Client();
    final response = await client.send(request);

    // Lê o stream linha a linha (eventos do Firebase são enviados em texto)
    await for (var line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      // Cada evento válido começa com "data: "
      if (line.startsWith('data: ')) {
        final jsonStr = line.substring(6).trim();

        // Ignora eventos vazios
        if (jsonStr == 'null' || jsonStr.isEmpty) continue;

        try {
          final data = jsonDecode(jsonStr);

          // O Firebase envia eventos no formato: {"path": "...", "data": {...}}
          if (data is Map && data.containsKey('data')) {
            final payload = data['data'];

            // Verifica se a estrutura do JSON está correta
            if (payload is Map &&
                payload.containsKey('ativo') &&
                payload.containsKey('dataHora') &&
                payload.containsKey('foiDetectado') &&
                payload.containsKey('nivelGas')) {
              // Converte o JSON em objeto FirebaseLeitura
              yield FirebaseLeitura.fromJson(
                Map<String, dynamic>.from(payload),
              );
            }
          }
        } catch (e) {
          print('Erro ao decodificar evento: $e');
        }
      }
    }

    // Fecha o cliente ao encerrar o stream
    client.close();
  }
}
