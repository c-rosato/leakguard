import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/services/db_service.dart';
import 'package:leakguard_mq2/models/historico_uso.dart';

/// ===============================================================
/// HistoricoUsoDao - Operacoes em `historicouso`
///
/// Responsabilidades:
/// - Inserir registros de historico de uso na tabela `historicouso`,
///   vinculando um usuario a uma descricao de acao.
/// - Retornar o ID do registro criado para eventual rastreamento.
///
/// Implementacao:
/// - Abre conexoes MySQL sob demanda via [DbService.openConnection].
/// - Executa `INSERT` em `historicouso` com campos `id_usuario` e `acao`,
///   deixando `dataHora` a cargo do `CURRENT_TIMESTAMP` do banco.
/// - Recupera o ID pela propriedade `insertId` e, se necessario, por
///   `LAST_INSERT_ID()` como fallback.
///
/// Uso:
/// - Utilizado por [HistoricoUsoService] para registrar acoes administrativas
///   relevantes executadas no sistema.
/// ===============================================================
class HistoricoUsoDao {
  final DbService dbService;

  HistoricoUsoDao(this.dbService);

  /// Insere um registro de historico de uso.
  Future<int> inserir(HistoricoUso historico) async {
    final MySqlConnection conn = await dbService.openConnection();

    try {
      final acao = historico.acao.replaceAll("'", "''");
      final idUsuario = historico.idUsuario;

      final result = await conn.query(
        "INSERT INTO historicouso (id_usuario, acao) "
        "VALUES ($idUsuario, '$acao')",
      );

      final insertId = result.insertId;
      if (insertId != null && insertId > 0) {
        return insertId;
      }

      final results = await conn.query('SELECT LAST_INSERT_ID()');
      if (results.isEmpty) {
        return 0;
      }

      final value = results.first[0];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    } finally {
      await conn.close();
    }
  }
}
