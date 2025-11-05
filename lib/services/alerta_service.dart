import 'package:leakguard_mq2/models/alerta.dart';
import 'package:leakguard_mq2/models/firebase_leitura.dart';
import 'package:leakguard_mq2/daos/alerta_dao.dart';

/// ===============================================================
/// AlertaService - Regras de negocio de alerta
///
/// Funcoes principais:
/// - Avaliar nivel de gas e registrar alerta quando ultrapassar limiar
/// - Vincular alerta a uma leitura (id_leitura)
///
/// Observacao:
/// - Limiar simples e fixo para projeto academico.
/// ===============================================================
class AlertaService {
  final AlertaDao alertaDao;
  final double limiar;

  // === 1. Construtor ===
  // limiar padrao = 200.0 ppm (pode ajustar conforme necessidade)
  //
  // === Onde alterar o valor critico (AINDA NAO DEFINIDO) ===
  // Quando o valor definitivo for decidido, ajuste-o aqui no parametro
  // padrao do construtor (ex.: AlertaService(limiar: 250.0)). Se preferir,
  // podemos ler de uma variavel no .env (ex.: ALERT_THRESHOLD) no futuro.
  AlertaService({required this.alertaDao, this.limiar = 200.0});

  // === 2. Avalia e registra alerta (se necessario) ===
  Future<int?> avaliarERegistrar({
    required FirebaseLeitura leituraFirebase,
    required int idLeitura,
  }) async {
    if (leituraFirebase.nivelGasPPM >= limiar) {
      final mensagem = 'Nivel de gas acima do limiar ($limiar ppm)';
      final alerta = Alerta(
        idLeitura: idLeitura,
        mensagem: mensagem,
        nivelGas: leituraFirebase.nivelGasPPM,
      );

      final idAlerta = await alertaDao.inserir(alerta);
      return idAlerta;
    }

    return null; // sem alerta
  }
}
