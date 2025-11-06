import 'package:leakguard_mq2/models/alerta.dart';
import 'package:leakguard_mq2/models/firebase_leitura.dart';
import 'package:leakguard_mq2/daos/alerta_dao.dart';

/// ===============================================================
/// AlertaService - Regras de negocio de alerta
///
/// O que faz:
/// - Avalia a leitura de gas contra um limiar simples e registra alerta.
/// - Vincula o alerta a uma leitura especifica (`id_leitura`).
///
/// Como faz:
/// - Compara `nivelGasPPM` com `limiar`.
/// - Cria um [Alerta] e chama [AlertaDao.inserir] para persistir.
///
/// Por que assim:
/// - Requisito didatico: gerar alerta quando o nivel superar um valor fixo.
///   Mantemos o valor no construtor para facilitar ajustes.
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
  // O que: verifica o nivel da leitura e grava alerta quando >= limiar.
  // Como: constroi o modelo [Alerta] e delega a [AlertaDao.inserir].
  // Por que: manter a regra de negocio isolada do DAO e do main.
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
