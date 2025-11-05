import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/services/db_service.dart';
import 'package:leakguard_mq2/models/alerta.dart';

/// ===============================================================
/// AlertaDao - Operacoes de persistencia em `alerta`
///
/// O que esta classe faz:
/// - Recebe uma instancia de [DbService] para abrir conexoes MySQL.
/// - Insere alertas gerados pelo [AlertaService].
/// - Devolve o ID criado para eventuais referencias futuras.
///
/// Observacao:
/// - A coluna `dataHora` possui default CURRENT_TIMESTAMP, portanto nao enviamos esse campo.
/// ===============================================================
class AlertaDao {
  final DbService dbService;

  // === 1. Construtor ===
  // Mantem a referencia do DbService (instanciado no main).
  AlertaDao(this.dbService);

  // === 2. Insere alerta e retorna o ID gerado ===
  //
  // Passos:
  // 1. Abre conexao.
  // 2. Escapa mensagem simples.
  // 3. Executa INSERT na tabela `alerta`.
  // 4. Busca o ultimo ID com `_obterUltimoId`.
  Future<int> inserir(Alerta alerta) async {
    final MySqlConnection conn = await dbService.openConnection();

    try {
      final idLeitura = alerta.idLeitura;
      final mensagem = alerta.mensagem.replaceAll("'", "''");
      final nivel = alerta.nivelGas;

      await conn.query(
        "INSERT INTO alerta (id_leitura, mensagem, nivelGas) "
        "VALUES ($idLeitura, '$mensagem', $nivel)",
      );

      return await _obterUltimoId(conn, tabela: 'alerta');
    } finally {
      await conn.close();
    }
  }

  // === 3. Obtem o ultimo ID gerado (com fallback) ===
  Future<int> _obterUltimoId(MySqlConnection conn, {required String tabela}) async {
    final lastInsert = await conn.query('SELECT LAST_INSERT_ID()');
    final idDireto = _extrairId(lastInsert);

    if (idDireto > 0) {
      return idDireto;
    }

    final fallback =
        await conn.query('SELECT id FROM $tabela ORDER BY id DESC LIMIT 1');
    return _extrairId(fallback);
  }

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
