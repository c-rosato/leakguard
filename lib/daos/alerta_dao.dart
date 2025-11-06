import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/services/db_service.dart';
import 'package:leakguard_mq2/models/alerta.dart';

/// ===============================================================
/// AlertaDao - Operacoes de persistencia em `alerta`
///
/// O que faz:
/// - Persiste alertas gerados a partir de leituras acima do limiar.
/// - Retorna o ID do alerta inserido.
///
/// Como faz:
/// - Abre conexao via [DbService.openConnection].
/// - Executa INSERT direto em `alerta` (sem `dataHora`, que usa CURRENT_TIMESTAMP).
/// - Recupera o ID por `LAST_INSERT_ID()` com fallback simples.
///
/// Por que assim:
/// - Mantem a camada de acesso a dados simples e didatica, sem frameworks.
///
/// Quem usa:
/// - [AlertaService.avaliarERegistrar] constroi o modelo e chama [inserir].
/// ===============================================================
class AlertaDao {
  final DbService dbService;

  // === 1. Construtor ===
  // Mantem a referencia do DbService (instanciado no main).
  AlertaDao(this.dbService);

  // === 2. Insere alerta e retorna o ID gerado ===
  // O que: grava um alerta relacionado a uma leitura especifica.
  // Como: abre conexao (DbService), executa INSERT e recupera ID.
  // Por que: disponibilizar o ID para referenciar em outras operacoes.
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
