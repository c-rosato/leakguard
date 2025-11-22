import 'package:leakguard_mq2/models/alerta.dart';
import 'package:leakguard_mq2/models/firebase_leitura.dart';
import 'package:leakguard_mq2/daos/alerta_dao.dart';

/// ===============================================================
/// AlertaService - Regras de geracao de alertas
///
/// Responsabilidades:
/// - Avaliar leituras no instante em que o sensor passa a detectar gas.
/// - Classificar o nivel de gas em "moderado" ou "critico" conforme faixa.
/// - Registrar alertas correspondentes na tabela `alerta`.
///
/// Implementacao:
/// - Compara `nivelGasPPM`, monta um [Alerta] com mensagem descritiva
///   e persiste via [AlertaDao] quando o nivel exige aviso.
/// ===============================================================
class AlertaService {
  final AlertaDao alertaDao;

  // === 1. Construtor ===
  AlertaService({required this.alertaDao});

  // === 2. Avalia e registra alerta na transicao de deteccao ===
  // O que: utilizado quando `gasDetectado` passa de false para true.
  // Como: define o tipo com base em `nivelGasPPM` e registra o alerta com
  //       mensagem especifica.
  //       - > 25 e < 30 => "Alerta moderado"
  //       - > 30        => "Alerta critico"
  // Retorno: tipo do alerta ("moderado"/"critico") quando criado; null caso contrario.
  Future<String?> avaliarERegistrarPorDeteccao({
    required FirebaseLeitura leituraFirebase,
    required int idLeitura,
  }) async {
    final nivel = leituraFirebase.nivelGasPPM;
    String? tipo;

    if (nivel > 25 && nivel < 30) {
      tipo = 'moderado';
    } else if (nivel > 30) {
      tipo = 'critico';
    }

    if (tipo != null) {
      final mensagem =
          'Alerta $tipo: nivel de gas ${nivel.toStringAsFixed(2)} ppm';
      final alerta = Alerta(
        idLeitura: idLeitura,
        mensagem: mensagem,
        nivelGas: nivel,
      );
      await alertaDao.inserir(alerta);
      return tipo;
    }

    return null;
  }
}

