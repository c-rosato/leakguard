import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/services/db_service.dart';
import 'package:leakguard_mq2/models/alerta.dart';

/// ===============================================================
/// AlertaDao - Operacoes de persistencia em `alerta`
///
/// Responsabilidades:
/// - Inserir registros na tabela `alerta` associados a uma leitura de gás.
/// - Retornar o ID do alerta gerado para rastreamento posterior.
///
/// Implementacao:
/// - Abre conexoes MySQL sob demanda via [DbService.openConnection].
/// - Executa `INSERT` direto em `alerta`, delegando `dataHora` ao
///   `CURRENT_TIMESTAMP` do banco.
/// - Recupera o ID gerado com `LAST_INSERT_ID()` e fallback por SELECT.
///
/// Uso:
/// - Consumido por [AlertaService] para registrar alertas derivados
///   de leituras que ultrapassam faixas de segurança.
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
  // O que: descobre o ultimo ID inserido para a tabela informada.
  // Como:
  //   - Primeiro consulta `LAST_INSERT_ID()` na conexao atual.
  //   - Se o valor for 0 ou invalido, busca o maior `id` da tabela
  //     com um SELECT ordenado em ordem decrescente.
  // Por que: garantir que um ID valido seja retornado mesmo em cenarios
  //          onde `LAST_INSERT_ID()` nao esteja disponivel.
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

  // === 4. Converte o resultado em inteiro ===
  // O que: extrai um valor numerico da primeira coluna do primeiro registro.
  // Como:
  //   - Verifica o tipo efetivo retornado (`int`, `num` ou outro).
  //   - Converte para `int`, tentando parse de string quando necessario.
  // Por que: padronizar a conversao de IDs retornados pelo driver `mysql1`
  //          e evitar repeticao dessa logica em varios pontos.
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
