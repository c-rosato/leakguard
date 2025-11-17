import 'package:intl/intl.dart';
import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/services/db_service.dart';
import 'package:leakguard_mq2/models/leitura_gas.dart';

/// ===============================================================
/// LeituraGasDao - Operacoes de persistencia em `leituragas`
///
/// Responsabilidades:
/// - Inserir leituras de gás na tabela `leituragas` com todos os campos
///   necessários para auditoria.
/// - Descobrir a localização atual de um dispositivo a partir da tabela
///   `dispositivo`.
///
/// Implementacao:
/// - Abre conexoes MySQL sob demanda via [DbService.openConnection].
/// - Ao inserir, utiliza a localizacao presente no modelo ou, se ausente,
///   faz um subselect em `dispositivo.id_localizacao` com fallback para 1
///   (localizacao padrao).
/// - Converte datas e tipos primitivos para representar fielmente o registro
///   no banco.
/// - Recupera o ID gerado com `LAST_INSERT_ID()` e fallback por SELECT.
///
/// Uso:
/// - Consumido por [LeituraService] para persistir leituras convertidas
///   a partir dos dados do Firebase.
/// ===============================================================
class LeituraGasDao {
  final DbService dbService;

  // === 1. Construtor ===
  // Mantem a referencia de [DbService] para abrir conexoes sempre que necessario.
  LeituraGasDao(this.dbService);

  // === 2. Insere leitura e retorna o ID gerado ===
  //
  // Fluxo:
  // 1. Abre conexao MySQL.
  // 2. Formata data/hora e converte `foiDetectado` para inteiro (1/0).
  // 3. Monta o valor de `id_localizacao` com base no modelo ou em subselect.
  // 4. Executa INSERT em `leituragas` e retorna o ID criado.
  Future<int> inserir(LeituraGas leitura) async {
    final MySqlConnection conn = await dbService.openConnection();

    try {
      // Preparo dos campos para INSERT:
      // - Formata a data da leitura.
      // - Converte o flag booleano para inteiro.
      // - Define o SQL que resolve a localizacao da leitura.
      final dataFmt = DateFormat('yyyy-MM-dd HH:mm:ss').format(leitura.dataHora);
      final foiInt = leitura.foiDetectado ? 1 : 0;
      final nivel = leitura.nivelGas;
      final idDisp = leitura.idDispositivo;
      // Resolucao de id_localizacao:
      // - Se fornecido no modelo, utiliza o valor diretamente.
      // - Caso contrario, utiliza a localizacao atual do dispositivo no banco,
      //   com fallback para a localizacao padrao (1).
      final idLocalizacaoSql = leitura.idLocalizacao == null
          ? "COALESCE((SELECT id_localizacao FROM dispositivo WHERE id = $idDisp), 1)"
          : leitura.idLocalizacao.toString();

      await conn.query(
        "INSERT INTO leituragas (id_dispositivo, id_localizacao, dataHora, foiDetectado, nivelGas) "
        "VALUES ($idDisp, $idLocalizacaoSql, '$dataFmt', $foiInt, $nivel)",
      );

      return await _obterUltimoId(conn, tabela: 'leituragas');
    } finally {
      await conn.close();
    }
  }

  // === 3. Obtem o ultimo ID gerado (com fallback simples) ===
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

  // === 4. Busca a localizacao atual do dispositivo ===
  // O que: retorna `dispositivo.id_localizacao` para um `idDispositivo`.
  // Como: SELECT simples, convertendo o tipo retornado pelo driver mysql1.
  // Por que: permitir ao service compor o modelo com a localizacao vigente.
  // Quem usa: [LeituraService.processarLeitura].
  Future<int?> obterLocalizacaoDoDispositivo({required int idDispositivo}) async {
    final MySqlConnection conn = await dbService.openConnection();

    try {
      final resultado = await conn.query(
        'SELECT id_localizacao FROM dispositivo WHERE id = $idDispositivo LIMIT 1',
      );

      if (resultado.isEmpty) {
        return null;
      }

      final valor = resultado.first['id_localizacao'];
      if (valor == null) {
        return null;
      }
      if (valor is int) {
        return valor;
      }
      if (valor is num) {
        return valor.toInt();
      }
      return int.tryParse(valor.toString());
    } finally {
      await conn.close();
    }
  }

}
