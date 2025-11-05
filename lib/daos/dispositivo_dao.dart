import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/services/db_service.dart';

/// ===============================================================
/// DispositivoDao - Operacoes de persistencia em `dispositivo`
///
/// O que esta classe faz:
/// - Recebe um [DbService], que sabe abrir conexoes MySQL.
/// - Executa INSERT/UPDATE diretamente na tabela `dispositivo`.
/// - Apoia o [DispositivoService] com metodos especificos (seed, atualizar ativo e fk).
///
/// Observacao:
/// - No projeto atual ha apenas um dispositivo (ID = 1), entao as consultas usam sempre esse ID.
/// ===============================================================
class DispositivoDao {
  final DbService dbService;

  // === 1. Construtor ===
  DispositivoDao(this.dbService);

  // === 2. Atualiza campo `ativo` do dispositivo ===
  //
  // Reutilizado pelo DispositivoService a cada leitura do Firebase.
  // Converte bool em inteiro (1/0) para gravar na coluna BOOLEAN do MySQL.
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
  //
  // Usado no startup para inserir o ESP32 se ainda nao existir.
  // Recebe opcionalmente o ID da localizacao padrao (FK).
  // Usa ON DUPLICATE KEY para atualizar a FK se o registro ja existir.
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
          'ON DUPLICATE KEY UPDATE id_localizacao = $localizacaoValor';
      await conn.query(sql);
    } finally {
      await conn.close();
    }
  }

  // === 4. Atualiza localizacao vinculada ao dispositivo ===
  //
  // Permite alterar a FK manualmente (menu) ou remover (NULL).
  // O valor ja chega pronto no service, entao apenas concatena no UPDATE.
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
