import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/services/db_service.dart';

/// ===============================================================
/// DispositivoDao - Operacoes de persistencia em `dispositivo`
///
/// Responsabilidades:
/// - Garantir que o registro de um dispositivo exista (seed por ID).
/// - Atualizar campos simples (`ativo`, `id_localizacao`) do dispositivo.
/// - Criar novos dispositivos com ID auto-incremento para uso administrativo.
///
/// Implementacao:
/// - Abre conexoes MySQL via [DbService.openConnection] para cada operacao.
/// - Usa `INSERT ... ON DUPLICATE KEY` para criar o dispositivo apenas
///   quando nao existir.
/// - Executa `UPDATE` para sincronizar o estado `ativo` e a FK de localizacao.
/// - Para inserts administrativos, utiliza `INSERT` com auto-incremento e
///   recupera o ID por `insertId` ou `LAST_INSERT_ID()` com fallback.
///
/// Uso:
/// - Consumido por [DispositivoService] para manter o cadastro de
///   dispositivos alinhado ao estado do sensor e aos comandos do administrador.
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

  // === 5. Lista todos os dispositivos ===
  Future<List<Map<String, dynamic>>> listarTodos() async {
    final MySqlConnection conn = await dbService.openConnection();

    try {
      final results = await conn.query(
        'SELECT id, nome, ativo, id_localizacao FROM dispositivo ORDER BY id',
      );

      return results.map((row) {
        final id = row[0] as int;
        final nome = row[1] as String;
        final ativoValor = row[2];
        final idLoc = row[3] as int?;

        final bool ativoBool;
        if (ativoValor is bool) {
          ativoBool = ativoValor;
        } else if (ativoValor is num) {
          ativoBool = ativoValor != 0;
        } else {
          ativoBool = ativoValor.toString() != '0';
        }
        
        return <String, dynamic>{
          'id': id,
          'nome': nome,
          'ativo': ativoBool,
          'id_localizacao': idLoc,
        };
      }).toList();
    } finally {
      await conn.close();
    }
  }

  // === 6. Cria um novo dispositivo (AUTO_INCREMENT) ===
  Future<int> inserirNovo({
    required String nome,
    required int idLocalizacao,
  }) async {
    final MySqlConnection conn = await dbService.openConnection();

    try {
      final nomeEscapado = nome.replaceAll("'", "''");

      final result = await conn.query(
        "INSERT INTO dispositivo (nome, ativo, id_localizacao) "
        "VALUES ('$nomeEscapado', 1, $idLocalizacao)",
      );

      // mysql1 expõe o ID gerado em `insertId`
      final insertId = result.insertId;
      if (insertId != null && insertId > 0) {
        return insertId;
      }

      // Fallback usando LAST_INSERT_ID()
      final results = await conn.query('SELECT LAST_INSERT_ID()');
      if (results.isNotEmpty) {
        final value = results.first[0];
        if (value is int && value > 0) return value;
        if (value is num && value.toInt() > 0) return value.toInt();
        final parsed = int.tryParse(value.toString());
        if (parsed != null && parsed > 0) return parsed;
      }

      // Fallback final: busca pelo ultimo ID com o mesmo nome
      final idResult = await conn.query(
        "SELECT id FROM dispositivo WHERE nome = '$nomeEscapado' "
        'ORDER BY id DESC LIMIT 1',
      );
      if (idResult.isNotEmpty) {
        final value = idResult.first[0];
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value.toString()) ?? 0;
      }

      return 0;
    } finally {
      await conn.close();
    }
  }
}
