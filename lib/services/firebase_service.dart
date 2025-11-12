import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:leakguard_mq2/models/firebase_leitura.dart';

/// ===============================================================
/// FirebaseService - Comunicacao com o Realtime Database
///
/// O que faz:
/// - Fornece leitura única e stream com polling de dados do sensor.
/// - Converte respostas JSON em [FirebaseLeitura].
///
/// Como faz:
/// - Realiza GET em `{baseUrl}{path}.json?auth={token}` com `package:http`.
/// - Na stream, emite na primeira leitura e quando houver transições de
///   detecção, alteração de `sensorAtivo`, redefinição de detecção ou mudança
///   de `nivelGasPPM`.
///
/// Interações:
/// - Consumido por camadas de orquestração para snapshot e processamento
///   contínuo.
/// ===============================================================
class FirebaseService {
  final String baseUrl;
  final String authToken;

  FirebaseService({
    required this.baseUrl,
    required this.authToken,
  });

  // === 1. Busca o estado atual do sensor (única leitura) ===
  // O que: retorna a leitura atual do caminho informado ou null.
  // Como: GET simples; decodifica JSON em [FirebaseLeitura] quando válido.
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
  // O que: emite leituras relevantes para processamento.
  // Como: GET periódico; avalia condições de emissão (primeira leitura,
  //       transições e mudanças de nível).
  // Intervalo: 3 segundos entre requisições.
  Stream<FirebaseLeitura?> listenToSensorData({String path = '/mq2'}) async* {
    final url = Uri.parse('$baseUrl$path.json?auth=$authToken');

    FirebaseLeitura? ultimaLeitura;
    var primeiraIteracao = true;

    while (true) {
      try {
        final response = await http.get(url);

        if (response.statusCode == 200 && response.body != 'null') {
          final data = jsonDecode(response.body);

          if (data is Map<String, dynamic>) {
            final leituraAtual = FirebaseLeitura.fromJson(data);

            // Condicao: emite quando houver deteccao, mudanca de ativo, reset de deteccao,
            // mudanca do nivel de gas ou na primeira leitura
            final detectouAgora = (ultimaLeitura == null && leituraAtual.gasDetectado) ||
                (ultimaLeitura != null &&
                    !ultimaLeitura.gasDetectado &&
                    leituraAtual.gasDetectado);
            final ativoMudou = ultimaLeitura != null &&
                ultimaLeitura.sensorAtivo != leituraAtual.sensorAtivo;
            final deteccaoRedefinida = ultimaLeitura != null &&
                ultimaLeitura.gasDetectado &&
                !leituraAtual.gasDetectado;
            final nivelMudou = ultimaLeitura != null &&
                ultimaLeitura.nivelGasPPM != leituraAtual.nivelGasPPM;

            if (detectouAgora || ativoMudou || deteccaoRedefinida || nivelMudou || primeiraIteracao) {
              yield leituraAtual;
            }

            // Atualiza a ultima leitura armazenada
            ultimaLeitura = leituraAtual;
            primeiraIteracao = false;
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
