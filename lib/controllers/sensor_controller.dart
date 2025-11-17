import 'dart:async';
import 'package:leakguard_mq2/models/firebase_leitura.dart';
import 'package:leakguard_mq2/services/firebase_service.dart';
import 'package:leakguard_mq2/services/dispositivo_service.dart';
import 'package:leakguard_mq2/services/leitura_service.dart';
import 'package:leakguard_mq2/services/alerta_service.dart';

/// ===============================================================
/// SensorController - Orquestra snapshot inicial e polling do MQ-2
///
/// Objetivo:
/// - Controlar a aquisição de leituras do Firebase e o processamento
///   associado.
///
/// Como faz:
/// - `processarSnapshotInicial`: obtém a leitura atual, prepara o dispositivo
///   e sincroniza o status ativo, emitindo logs conforme a leitura.
/// - `iniciarPolling`: consome a stream com polling, persiste variações
///   relevantes e gera alertas em transições de detecção.
///
/// Interações:
/// - Integra [FirebaseService], [DispositivoService], [LeituraService] e
///   [AlertaService].
/// - Mantém a última leitura processada para comparação.
/// ===============================================================
class SensorController {
  final FirebaseService firebase;
  final DispositivoService dispositivoService;
  final LeituraService leituraService;
  final AlertaService alertaService;

  FirebaseLeitura? _ultimaLeituraProcessada;

  SensorController({
    required this.firebase,
    required this.dispositivoService,
    required this.leituraService,
    required this.alertaService,
  });

  // === Snapshot inicial ===
  // O que: obtém o estado atual do sensor e sincroniza dispositivo e status
  //       ativo.
  // Como: consulta o Firebase, executa seed do dispositivo e alinha o campo
  //       ativo; emite logs conforme detecção e PPM.
  // Entrada: `idLocalizacaoPadrao` para criação do dispositivo quando
  //          necessário.
  Future<void> processarSnapshotInicial({required int idLocalizacaoPadrao}) async {
    final leituraAtual = await firebase.getCurrentSensorData();
    if (leituraAtual != null) {
      await dispositivoService.seedDispositivo(
        idDispositivo: leituraAtual.idDispositivo,
        idLocalizacaoPadrao: idLocalizacaoPadrao,
      );
      await dispositivoService.sincronizarAtivo(
        idDispositivo: leituraAtual.idDispositivo,
        leituraFirebase: leituraAtual,
      );

      if (leituraAtual.gasDetectado) {
        print('Ultima leitura do sensor (detecao de gas): $leituraAtual');
      } else {
        print('Ultima leitura do sensor: $leituraAtual');
        print('Nenhum dado atual com detecao de gas encontrado.');
      }
    } else {
      print('Nenhum dado encontrado no Firebase (no /mq2 vazio).');
    }
  }

  // === Polling contínuo ===
  // O que: inicia a escuta contínua das leituras e aplica regras de
  //       persistência e alerta.
  // Como: assina a stream do Firebase; a cada evento, garante dispositivo,
  //       sincroniza status, persiste variações de nível e avalia alertas em
  //       transições de detecção.
  // Retorno: `StreamSubscription` para controle externo.
  StreamSubscription<FirebaseLeitura?> iniciarPolling({
    required int idLocalizacaoPadrao,
    String path = '/mq2',
  }) {
    print('Escutando leituras do sensor MQ-2 (polling a cada 3 segundos)...\n');
    print('Comandos: digite "menu" para abrir o menu ou "sair" para encerrar.');

    final subscription = firebase.listenToSensorData(path: path).listen(
      (leitura) async {
        if (leitura == null) {
          return;
        }

        try {
          await dispositivoService.seedDispositivo(
            idDispositivo: leitura.idDispositivo,
            idLocalizacaoPadrao: idLocalizacaoPadrao,
          );
          await dispositivoService.sincronizarAtivo(
            idDispositivo: leitura.idDispositivo,
            leituraFirebase: leitura,
          );

          if (_ultimaLeituraProcessada == null) {
            _ultimaLeituraProcessada = leitura;
            return; // ignora primeiro evento apenas para inicializar estado
          }

          // Regra 1: leituras comuns só quando o nível muda
          final nivelMudou = _ultimaLeituraProcessada!.nivelGasPPM !=
              leitura.nivelGasPPM;

          int? leituraId;
          if (nivelMudou) {
            leituraId = await leituraService.processarLeitura(leitura);
          }

          // Regra 2: alerta depende apenas do valor do nível de gás
          final tipo = await alertaService.avaliarERegistrarPorDeteccao(
            leituraFirebase: leitura,
            // se ainda nao gravou a leitura nesta iteracao, grava aqui para ter o id
            idLeitura: leituraId ?? await leituraService.processarLeitura(leitura),
          );
          if (tipo != null) {
            print('Alerta $tipo: $leitura');
          }

          _ultimaLeituraProcessada = leitura;

        } catch (e) {
          print('Erro ao processar leitura e regras: $e');
        }
      },
      onError: (error) => print('Erro ao consultar Firebase: $error'),
      cancelOnError: false,
    );

    return subscription;
  }
}
