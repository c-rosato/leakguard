import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/services/db_service.dart';
import 'package:leakguard_mq2/models/localizacao.dart';

/// ===============================================================
/// LocalizacaoDao - Operacoes de persistencia em `localizacao`
///
/// Responsabilidades:
/// - Listar localizacoes cadastradas para exibição ou validação.
/// - Inserir novas localizacoes na tabela `localizacao`.
/// - Garantir a existência de uma localizacao padrão com ID conhecido.
///
/// Implementacao:
/// - Abre conexoes MySQL sob demanda via [DbService.openConnection].
/// - Utiliza SELECT simples para carregar id, nome e descricao.
/// - Usa `INSERT` e `INSERT ... ON DUPLICATE KEY` para criar registros,
///   com recuperação do último ID por `LAST_INSERT_ID()` e fallback.
///
/// Uso:
/// - Consumido por [LocalizacaoService] para operações de cadastro,
///   listagem e seed da localização padrão.
/// ===============================================================
class LocalizacaoDao {
  final DbService dbService;

  LocalizacaoDao(this.dbService);

  // === 1. Lista todas as localizacoes ===
  // O que: retorna todas as linhas da tabela `localizacao`.
  // Como: executa SELECT simples trazendo id, nome_local e descricao,
  //       ordenado pelo ID.
  // Por que: disponibilizar dados para consultas e exibicao nos menus.
  Future<List<Localizacao>> listarTodas() async {
    final conn = await dbService.openConnection();

    try {
      final results = await conn.query(
        'SELECT id, nome_local, descricao FROM localizacao ORDER BY id',
      );

      return results.map((row) {
        final id = row[0] as int;
        final nome = row[1] as String;
        final desc = row[2] as String?;

        return Localizacao(
          id: id,
          nomeLocal: nome,
          descricao: desc,
        );
      }).toList();
    } finally {
      await conn.close();
    }
  }

  // === 2. Insere uma nova localizacao ===
  // O que: cria um registro na tabela `localizacao` com nome e descricao.
  // Como: abre conexao, escapa os textos e executa INSERT.
  // Por que: permitir cadastro de novos ambientes pelo administrador.
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

  // === 3. Garante a localizacao padrao ===
  // O que: cria ou atualiza uma localizacao com ID fixo (por exemplo, 1).
  // Como: usa `INSERT ... ON DUPLICATE KEY UPDATE` para manter nome e descricao.
  // Por que: assegurar uma FK estavel utilizada como base por outros registros.
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
  // O que: determina o ultimo ID inserido em `localizacao`.
  // Como: consulta `LAST_INSERT_ID()` e, se necessario, busca o maior ID.
  // Por que: devolver ao chamador o identificador da localizacao criada.
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

  // === 5. Converte o valor retornado em inteiro ===
  // O que: extrai o valor numerico da primeira coluna do primeiro registro.
  // Como: trata os possiveis tipos retornados (`int`, `num` ou `String`).
  // Por que: padronizar a conversao de IDs vindos do MySQL.
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
