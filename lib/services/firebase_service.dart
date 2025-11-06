import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:leakguard_mq2/models/firebase_leitura.dart';

/// ===============================================================
/// FirebaseService - Comunicacao com o Realtime Database
///
/// O que faz:
/// - Consulta o Firebase Realtime Database e entrega [FirebaseLeitura] ao app.
/// - Fornece leitura unica e uma stream com polling simples.
///
/// Como faz:
/// - Usa `package:http` para GET no endpoint `{baseUrl}{path}.json?auth={token}`.
/// - Converte JSON em [FirebaseLeitura] via `FirebaseLeitura.fromJson`.
/// - Na stream, aplica regras para evitar emitir eventos redundantes.
///
/// Por que assim:
/// - Mantem a aplicacao console sem sockets, com logica clara e didatica.
///
/// Quem usa:
/// - `bin/main.dart` para obter snapshot inicial e consumir a stream de leituras.
/// ===============================================================
class FirebaseService {
  final String baseUrl;
  final String authToken;

  FirebaseService({
    required this.baseUrl,
    required this.authToken,
  });

  // === 1. Busca o estado atual do sensor uma unica vez ===
  // O que: retorna a leitura atual (ou null) do caminho informado.
  // Como: GET simples, parse JSON e factory [FirebaseLeitura.fromJson].
  // Por que: exibir snapshot inicial e sincronizar status do dispositivo.
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

  // === 2. Stream com polling continuo (a cada 3 segundos) ===
  // O que: emite leituras quando houver razao relevante.
  // Como: GET periodico; emite se detectou gas, mudou `sensorAtivo`,
  //        houve redefinicao ou e a primeira iteracao.
  // Por que: reduzir ruido no processamento do `main.dart`.
  // Quem usa: `bin/main.dart` para alimentar Dispositivo/Leitura/Alerta services.
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

            // Condicao: emite quando houver deteccao, mudanca de ativo, reset de deteccao ou primeira leitura
            final detectouAgora = (ultimaLeitura == null && leituraAtual.gasDetectado) ||
                (ultimaLeitura != null &&
                    !ultimaLeitura.gasDetectado &&
                    leituraAtual.gasDetectado);
            final ativoMudou = ultimaLeitura != null &&
                ultimaLeitura.sensorAtivo != leituraAtual.sensorAtivo;
            final deteccaoRedefinida = ultimaLeitura != null &&
                ultimaLeitura.gasDetectado &&
                !leituraAtual.gasDetectado;

            if (detectouAgora || ativoMudou || deteccaoRedefinida || primeiraIteracao) {
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
