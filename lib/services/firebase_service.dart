import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:leakguard_mq2/models/firebase_leitura.dart';

/// ===============================================================
/// FirebaseService - Comunicacao com o Realtime Database
///
/// O que esta classe faz:
/// - Recebe a `baseUrl` do Firebase e o `authToken` gerado no AuthService.
/// - Utiliza o `package:http` para montar e enviar requisicoes REST.
/// - Converte as respostas em objetos [FirebaseLeitura] para o restante do sistema.
/// - Mantem um loop de polling simples que simula uma stream continua.
///
/// Porque existe:
/// Sem WebSocket, o console precisa consultar o Firebase a cada 3 segundos
/// e decidir quando repassar a leitura (detectou gas, mudou o estado do
/// dispositivo ou e a primeira leitura).
/// ===============================================================
class FirebaseService {
  final String baseUrl;
  final String authToken;

  FirebaseService({
    required this.baseUrl,
    required this.authToken,
  });

  // === 1. Busca o estado atual do sensor uma unica vez ===
  //
  // Como funciona:
  // - Monta a URL (base + caminho + token).
  // - Faz um GET simples usando http.get.
  // - Se houver dados, converte para [FirebaseLeitura] chamando o factory.
  // - Erros sao tratados com mensagens no console (sem excecoes propagadas).
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
  //
  // Como funciona:
  // - Repete GETs a cada 3 segundos analisando a resposta JSON.
  // - Converte o resultado em [FirebaseLeitura].
  // - Emite a mesma leitura somente quando houver motivo (deteccao, mudanca
  //   do status `sensorAtivo` ou primeira rodada).
  // - Essa stream e consumida diretamente no main.dart para alimentar
  //   os servicos de dispositivo, leitura e alerta.
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
