import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:leakguard_mq2/models/firebase_leitura.dart';

/// ===============================================================
/// FirebaseService - Comunicação com o Realtime Database
///
/// Função principal:
/// - Realizar requisições periódicas (polling) ao Firebase
/// - Converter a resposta JSON em objeto [FirebaseLeitura]
/// - Emitir atualizações apenas quando o estado muda
///
/// Observação:
/// O polling ocorre a cada 3 segundos, simulando uma stream
/// de dados contínua sem depender de WebSocket.
/// ===============================================================
class FirebaseService {
  final String baseUrl;
  final String authToken;

  FirebaseService({
    required this.baseUrl,
    required this.authToken,
  });

  // === 1. Busca o estado atual do sensor uma única vez ===
  Future<FirebaseLeitura?> getCurrentSensorData({String path = '/mq2'}) async {
    final url = Uri.parse('$baseUrl$path.json?auth=$authToken');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200 && response.body != 'null') {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return FirebaseLeitura.fromJson(data);
        }
      } else {
        print('Erro ao consultar Firebase: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro na leitura do Firebase: $e');
    }

    return null;
  }

  // === 2. Stream com polling contínuo (a cada 3 segundos) ===
  //
  // Emite leituras APENAS quando:
  // - O valor de `foiDetectado` muda de false → true
  Stream<FirebaseLeitura?> listenToSensorData({String path = '/mq2'}) async* {
    final url = Uri.parse('$baseUrl$path.json?auth=$authToken');

    FirebaseLeitura? ultimaLeitura;

    while (true) {
      try {
        final response = await http.get(url);

        if (response.statusCode == 200 && response.body != 'null') {
          final data = jsonDecode(response.body);

          if (data is Map<String, dynamic>) {
            final leituraAtual = FirebaseLeitura.fromJson(data);

            // Condição: só emite se houve mudança de estado de detecção
            final mudouDeFalseParaTrue = (ultimaLeitura != null &&
                !ultimaLeitura.gasDetectado &&
                leituraAtual.gasDetectado);


            if (mudouDeFalseParaTrue) {
              yield leituraAtual;
            }

            // Atualiza a última leitura armazenada
            ultimaLeitura = leituraAtual;
          }
        } else {
          print('Erro ao consultar Firebase: ${response.statusCode}');
        }
      } catch (e) {
        print('Erro na leitura do Firebase: $e');
      }

      await Future.delayed(const Duration(seconds: 3));
    }
  }
}
