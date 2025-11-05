import 'package:intl/intl.dart';
import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/services/db_service.dart';
import 'package:leakguard_mq2/models/leitura_gas.dart';

/// ===============================================================
/// LeituraGasDao - Operacoes de persistencia em `leituragas`
///
/// O que esta classe faz:
/// - Recebe uma referencia de [DbService] e abre conexoes MySQL sob demanda.
/// - Insere registros criados pelo [LeituraService].
/// - Retorna o ID gerado para que o [AlertaService] vincule eventual alerta.
///
/// Observacao:
/// - Datas sao formatadas no padrao `yyyy-MM-dd HH:mm:ss`, compatível com DATETIME.
/// ===============================================================
class LeituraGasDao {
  final DbService dbService;

  // === 1. Construtor ===
  // Guarda o DbService para reutilizar a mesma configuracao de conexao.
  LeituraGasDao(this.dbService);

  // === 2. Insere leitura e retorna o ID gerado ===
  //
  // Passos:
  // 1. Abre conexao MySQL.
  // 2. Formata data/hora e converte bool em inteiro.
  // 3. Executa INSERT na tabela `leituragas`.
  // 4. Busca o ultimo ID usando `_obterUltimoId`.
  Future<int> inserir(LeituraGas leitura) async {
    final MySqlConnection conn = await dbService.openConnection();

    try {
      final dataFmt = DateFormat('yyyy-MM-dd HH:mm:ss').format(leitura.dataHora);
      final foiInt = leitura.foiDetectado ? 1 : 0;
      final nivel = leitura.nivelGas;
      final idDisp = leitura.idDispositivo;

      await conn.query(
        "INSERT INTO leituragas (id_dispositivo, dataHora, foiDetectado, nivelGas) "
        "VALUES ($idDisp, '$dataFmt', $foiInt, $nivel)",
      );

      return await _obterUltimoId(conn, tabela: 'leituragas');
    } finally {
      await conn.close();
    }
  }

  // === 3. Obtem o ultimo ID gerado (com fallback simples) ===
  //
  // Tenta FIRST: LAST_INSERT_ID() para aproveitar a conexao atual.
  // Caso venha 0, faz SELECT descendente da tabela para garantir o valor.
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
