import 'package:intl/intl.dart';
import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/services/db_service.dart';
import 'package:leakguard_mq2/models/leitura_gas.dart';

/// ===============================================================
/// LeituraGasDao - Operacoes de persistencia em `leituragas`
///
/// O que faz:
/// - Persiste leituras de gas na tabela `leituragas`.
/// - Fornece utilitario para descobrir a localizacao atual de um dispositivo.
///
/// Como faz:
/// - Abre conexoes sob demanda via [DbService.openConnection].
/// - No `inserir`, preenche `id_localizacao` de forma robusta usando o valor
///   do modelo, ou um subselect em `dispositivo.id_localizacao` com fallback
///   para `1` (localizacao padrao garantida pelo seed).
///
/// Por que assim:
/// - Mantemos a "fotografia" da localizacao no momento da leitura para
///   preservar historico, mesmo que o dispositivo mude de lugar depois.
/// - O subselect evita problemas de timing entre camadas e garante FK sempre.
///
/// Quem usa:
/// - [LeituraService.processarLeitura] cria o modelo e chama [inserir] para
///   gravar a leitura. Pode tambem usar [obterLocalizacaoDoDispositivo] para
///   compor o modelo antes do insert.
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
  // 3. Executa INSERT na tabela `leituragas`, incluindo `id_localizacao`.
  // 4. Busca o ultimo ID usando `_obterUltimoId`.
  Future<int> inserir(LeituraGas leitura) async {
    final MySqlConnection conn = await dbService.openConnection();

    try {
      // O que: prepara campos para INSERT.
      // Como: formata data, converte bool e monta SQL do id_localizacao.
      // Por que: manter SQL claro e lidar com tipos/NULL de forma simples.
      final dataFmt = DateFormat('yyyy-MM-dd HH:mm:ss').format(leitura.dataHora);
      final foiInt = leitura.foiDetectado ? 1 : 0;
      final nivel = leitura.nivelGas;
      final idDisp = leitura.idDispositivo;
      // Preenche id_localizacao de forma robusta:
      // - Se veio no modelo, usa diretamente.
      // - Se nao veio, busca no proprio MySQL a localizacao atual do dispositivo
      //   e aplica fallback para 1 (localizacao padrao semeada).
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
