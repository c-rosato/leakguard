import 'package:leakguard_mq2/models/alerta.dart';
import 'package:leakguard_mq2/models/firebase_leitura.dart';
import 'package:leakguard_mq2/daos/alerta_dao.dart';

/// ===============================================================
/// AlertaService - Regras de geração de alertas
///
/// O que faz:
/// - Avalia leituras no instante de detecção e persiste alertas conforme
///   faixas definidas.
/// - Classifica níveis: moderado (>20 e <30) e crítico (>30).
///
/// Como faz:
/// - Compara `nivelGasPPM`, cria um [Alerta] e persiste via [AlertaDao].
/// ===============================================================
class AlertaService {
  final AlertaDao alertaDao;

  // === 1. Construtor ===
  AlertaService({required this.alertaDao});

  // === 2. Avalia e registra alerta na transição de detecção ===
  // O que: utilizado quando `gasDetectado` passa de false para true.
  // Como: define o tipo por `nivelGasPPM` e registra o alerta com mensagem
  //       específica.
  //       - > 20 e < 30 => "Alerta moderado"
  //       - > 30        => "Alerta critico"
  // Retorno: tipo do alerta ("moderado"/"critico") quando criado; null caso contrário.
  Future<String?> avaliarERegistrarPorDeteccao({
    required FirebaseLeitura leituraFirebase,
    required int idLeitura,
  }) async {
    final nivel = leituraFirebase.nivelGasPPM;
    String? tipo;

    if (nivel > 20 && nivel < 30) {
      tipo = 'moderado';
    } else if (nivel > 30) {
      tipo = 'critico';
    }

    if (tipo != null) {
      final mensagem = 'Alerta $tipo: nivel de gas ${nivel.toStringAsFixed(2)} ppm';
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
