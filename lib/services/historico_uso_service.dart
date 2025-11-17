import 'package:leakguard_mq2/daos/historico_uso_dao.dart';
import 'package:leakguard_mq2/models/historico_uso.dart';

/// ===============================================================
/// HistoricoUsoService - Regras simples para `historicouso`
///
/// Responsabilidades:
/// - Registrar acoes relevantes executadas por usuarios na tabela
///   `historicouso`.
///
/// Implementacao:
/// - Constrói instancias de [HistoricoUso] e delega a persistencia
///   ao [HistoricoUsoDao].
/// ===============================================================
class HistoricoUsoService {
  final HistoricoUsoDao historicoUsoDao;

  HistoricoUsoService({required this.historicoUsoDao});

  Future<void> registrarAcao({
    required int idUsuario,
    required String acao,
  }) async {
    final historico = HistoricoUso(
      idUsuario: idUsuario,
      acao: acao,
    );
    await historicoUsoDao.inserir(historico);
  }
}
