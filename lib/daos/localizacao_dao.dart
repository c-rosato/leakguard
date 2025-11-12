import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/services/db_service.dart';
import 'package:leakguard_mq2/models/localizacao.dart';

/// ===============================================================
/// LocalizacaoDao - Operacoes de persistencia em `localizacao`
///
/// O que faz:
/// - Lista, cria e garante a existência de uma localização padrão.
///
/// Como faz:
/// - Abre conexões sob demanda via [DbService.openConnection].
/// - Executa INSERT simples (com escape básico) e seed idempotente com
///   `INSERT ... ON DUPLICATE KEY`.
/// - Recupera IDs com `LAST_INSERT_ID()` e possui fallback por consulta.
///
/// Quem usa:
/// - [LocalizacaoService] delega criação e seed para este DAO.
/// ===============================================================
class LocalizacaoDao {
  final DbService dbService;

  // === 1. Construtor ===
  //
  // O DbService é injetado externamente. Mantém a referência para abrir
  // conexões sempre que uma operação for executada.
  LocalizacaoDao(this.dbService);

  // === 1.1. Lista todas as localizações ordenadas pelo nome ===
  // O que: retorna todas as localizações existentes.
  // Como: SELECT simples mapeando linhas para o modelo [Localizacao].
  Future<List<Localizacao>> listarTodas() async {
    final conn = await dbService.openConnection();

    try {
      final results = await conn.query(
        'SELECT id, nome_local, descricao FROM localizacao ORDER BY nome_local',
      );

      return results
          .map((row) => Localizacao(
                id: row['id'] as int?,
                nomeLocal: row['nome_local'] as String,
                descricao: row['descricao'] as String?,
              ))
          .toList();
    } finally {
      await conn.close();
    }
  }

  // === 2. Insere localizacao e retorna o ID ===
  // O que: cria um novo registro em `localizacao` e retorna o ID gerado.
  // Como: abre conexão (DbService), escapa campos e executa INSERT.
  Future<int> inserir(Localizacao localizacao) async {
    final conn = await dbService.openConnection();

    try {
      final nome = localizacao.nomeLocal.replaceAll("'", "''");
      final descricao = localizacao.descricao == null
          ? 'NULL'
          : "'${localizacao.descricao!.replaceAll("'", "''")}'";

      await conn.query(
        "INSERT INTO localizacao (nome_local, descricao) VALUES ('$nome', $descricao)",
      );

      return await _obterUltimoId(conn);
    } finally {
      await conn.close();
    }
  }

  // === 3. Seed padrão com ID conhecido ===
  // O que: cria/atualiza a localização padrão com ID estável (ex.: 1).
  // Como: `INSERT ... ON DUPLICATE KEY UPDATE` para garantir idempotência.
  // Quem usa: [LocalizacaoService.seedLocalizacaoPadrao].
  Future<int> seedPadrao({
    required int idLocalizacao,
    required String nomePadrao,
    required String descricaoPadrao,
  }) async {
    final conn = await dbService.openConnection();

    try {
      final nome = nomePadrao.replaceAll("'", "''");
      final descricao = descricaoPadrao.replaceAll("'", "''");

      await conn.query(
        "INSERT INTO localizacao (id, nome_local, descricao) "
        "VALUES ($idLocalizacao, '$nome', '$descricao') "
        "ON DUPLICATE KEY UPDATE "
        "nome_local = VALUES(nome_local), "
        "descricao = VALUES(descricao)",
      );

      return idLocalizacao;
    } finally {
      await conn.close();
    }
  }

  // === 4. Recupera o último ID gerado ===
  //
  // Usa LAST_INSERT_ID() na mesma conexão. Caso retorne zero, realiza um
  // SELECT para obter o maior ID existente.
  Future<int> _obterUltimoId(MySqlConnection conn) async {
    final lastInsert = await conn.query('SELECT LAST_INSERT_ID()');
    final idDireto = _extrairId(lastInsert);

    if (idDireto > 0) {
      return idDireto;
    }

    final fallback =
        await conn.query('SELECT id FROM localizacao ORDER BY id DESC LIMIT 1');
    return _extrairId(fallback);
  }

  // === 5. Converte o valor retornado pelo MySQL em int ===
  //
  // O pacote mysql1 pode retornar int, num ou string. Centraliza a
  // conversão para reutilização em diferentes consultas.
  int _extrairId(Results results) {
    if (results.isEmpty) {
      return 0;
    }

    final value = results.first[0];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString()) ?? 0;
  }
}
