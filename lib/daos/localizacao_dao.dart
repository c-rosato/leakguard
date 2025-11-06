import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/services/db_service.dart';
import 'package:leakguard_mq2/models/localizacao.dart';

/// ===============================================================
/// LocalizacaoDao - Operacoes de persistencia em `localizacao`
///
/// O que faz:
/// - Cria localizacoes e garante a existencia de uma localizacao padrao.
///
/// Como faz:
/// - Abre conexoes sob demanda via [DbService.openConnection].
/// - Executa INSERT simples (com escape basico) e seed idempotente com
///   `INSERT ... ON DUPLICATE KEY`.
/// - Recupera IDs com `LAST_INSERT_ID()` + fallback.
///
/// Por que assim:
/// - Manter a camada de dados direta e clara para o projeto didatico.
///
/// Quem usa:
/// - [LocalizacaoService] delega criacao e seed para este DAO.
/// ===============================================================
class LocalizacaoDao {
  final DbService dbService;

  // === 1. Construtor ===
  //
  // O DbService e injetado no main.dart. Aqui apenas guardamos a referencia
  // para abrir conexoes sempre que uma operacao for executada.
  LocalizacaoDao(this.dbService);

  // === 2. Insere localizacao e retorna o ID ===
  // O que: cria um novo registro em `localizacao`.
  // Como: abre conexao (DbService), escapa campos e executa INSERT.
  // Por que: disponibilizar o ID para uso imediato em relacionamentos.
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

  // === 3. Seed padrao com ID conhecido ===
  // O que: cria/atualiza a localizacao padrao com ID estavel (ex.: 1).
  // Como: `INSERT ... ON DUPLICATE KEY UPDATE` para garantir idempotencia.
  // Por que: outras tabelas dependem da existencia desta FK.
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

  // === 4. Recupera o ultimo ID gerado ===
  //
  // Preferimos usar LAST_INSERT_ID() (funciona enquanto estiver na mesma
  // conexao). Caso o driver devolva zero, fazemos um SELECT simples para
  // pegar o maior ID existente.
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
  // O pacote mysql1 pode retornar int, num ou string. Centralizamos
  // a conversao aqui para reaproveitar em diferentes consultas.
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
