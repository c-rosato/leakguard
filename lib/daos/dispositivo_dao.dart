import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/services/db_service.dart';

/// ===============================================================
/// DispositivoDao - Operacoes de persistencia em `dispositivo`
///
/// O que faz:
/// - Garante existencia do dispositivo (seed) e atualiza campos simples.
/// - Permite vincular/desvincular a localizacao (FK) do dispositivo.
///
/// Como faz:
/// - Abre conexao via [DbService.openConnection] sob demanda.
/// - Usa SQL direto com `INSERT ... ON DUPLICATE KEY` para o seed.
/// - Atualiza `ativo` e `id_localizacao` com `UPDATE` simples.
///
/// Por que assim:
/// - Deixa a camada didatica, previsivel e sem dependencias externas.
///
/// Quem usa:
/// - [DispositivoService] chama os metodos abaixo para manter o estado.
/// ===============================================================
class DispositivoDao {
  final DbService dbService;

  // === 1. Construtor ===
  DispositivoDao(this.dbService);

  // === 2. Atualiza campo `ativo` do dispositivo ===
  // O que: sincroniza o status de atividade informado pelo Firebase.
  // Como: converte bool em inteiro (1/0) e executa UPDATE.
  // Por que: refletir no banco o estado operacional do dispositivo.
  // Quem usa: [DispositivoService.sincronizarAtivo].
  Future<int> atualizarAtivo({required int idDispositivo, required bool ativo}) async {
    final MySqlConnection conn = await dbService.openConnection();

    try {
      final ativoInt = ativo ? 1 : 0;
      final sql = 'UPDATE dispositivo SET ativo = $ativoInt WHERE id = $idDispositivo';
      final result = await conn.query(sql);

      return result.affectedRows ?? 0;
    } finally {
      await conn.close();
    }
  }

  // === 3. Seed simples do dispositivo (garante que o ID exista) ===
  // O que: cria o dispositivo se nao existir, sem sobrescrever dados existentes.
  // Como: `INSERT ... ON DUPLICATE KEY UPDATE id = id` (no-op quando existe).
  // Por que: permitir startup/loop idempotente.
  // Quem usa: [DispositivoService.seedDispositivo].
  Future<void> seedSeNecessario({
    required int idDispositivo,
    String nomePadrao = 'ESP32 MQ-2',
    int? idLocalizacao,
  }) async {
    final MySqlConnection conn = await dbService.openConnection();

    try {
      final nomeEscapado = nomePadrao.replaceAll("'", "''");
      final localizacaoValor =
          idLocalizacao == null ? 'NULL' : idLocalizacao.toString();

      final sql =
          "INSERT INTO dispositivo (id, nome, ativo, id_localizacao) VALUES ($idDispositivo, '${nomeEscapado}', 1, $localizacaoValor) "
          'ON DUPLICATE KEY UPDATE id = id';
      await conn.query(sql);
    } finally {
      await conn.close();
    }
  }

  // === 4. Atualiza localizacao vinculada ao dispositivo ===
  // O que: define/remover `id_localizacao` do dispositivo.
  // Como: UPDATE simples, aceitando `NULL` quando idLocalizacao nao informado.
  // Por que: refletir a alocacao fisica do equipamento.
  // Quem usa: [DispositivoService.vincularLocalizacao].
  Future<int> atualizarLocalizacao({required int idDispositivo, required int? idLocalizacao}) async {
    final MySqlConnection conn = await dbService.openConnection();

    try {
      final valor = idLocalizacao == null ? 'NULL' : idLocalizacao.toString();
      final result = await conn.query(
        'UPDATE dispositivo SET id_localizacao = $valor WHERE id = $idDispositivo',
      );

      return result.affectedRows ?? 0;
    } finally {
      await conn.close();
    }
  }
}
