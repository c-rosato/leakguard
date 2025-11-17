import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/models/localizacao.dart';
import 'package:leakguard_mq2/models/leitura_gas.dart';
import 'package:leakguard_mq2/models/alerta.dart';
import 'package:leakguard_mq2/models/historico_uso.dart';

/// ===============================================================
/// MenuReadDao - Consultas simples para o menu (VIEW)
///
/// Responsabilidades:
/// - Executar consultas de leitura para popular o menu de console:
///   dispositivos, localizacoes, leituras, alertas e historico de uso.
///
/// Implementacao:
/// - Utiliza uma unica instancia de [MySqlConnection] compartilhada,
///   recebida via construtor, exclusivamente para SELECTs do menu.
/// - Nao fecha a conexao; o ciclo de vida e controlado por quem cria.
/// ===============================================================
class MenuReadDao {
  final MySqlConnection conn;

  MenuReadDao(this.conn);

  // === 1. Lista dispositivos para o menu ===
  // O que: retorna ID, nome, status `ativo` e id_localizacao dos dispositivos.
  // Como: executa SELECT ordenado pelo ID, convertendo o campo ativo para bool.
  // Por que: exibir no menu o estado atual de cada dispositivo.
  Future<List<Map<String, dynamic>>> listarDispositivos() async {
    final results = await conn.query(
      'SELECT id, nome, ativo, id_localizacao FROM dispositivo ORDER BY id',
    );

    return results.map((row) {
      final id = row[0] as int;
      final nome = row[1] as String;
      final ativoValor = row[2];
      final idLoc = row[3] as int?;

      final bool ativoBool;
      if (ativoValor is bool) {
        ativoBool = ativoValor;
      } else if (ativoValor is num) {
        ativoBool = ativoValor != 0;
      } else {
        ativoBool = ativoValor.toString() != '0';
      }

      return <String, dynamic>{
        'id': id,
        'nome': nome,
        'ativo': ativoBool,
        'id_localizacao': idLoc,
      };
    }).toList();
  }

  // === 2. Lista localizacoes para o menu ===
  // O que: retorna todas as localizacoes cadastradas.
  // Como: SELECT simples em `localizacao`, mapeando para o modelo [Localizacao].
  // Por que: permitir ao menu exibir ambientes disponiveis.
  Future<List<Localizacao>> listarLocalizacoes() async {
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
  }

  // === 3. Lista leituras de gas ===
  // O que: retorna leituras registradas em `leituragas`, mais recentes primeiro.
  // Como: SELECT com campos principais e conversao de tipos (DateTime, bool, double).
  // Por que: exibir historico de leituras no menu sem acessar diretamente os DAOs.
  Future<List<LeituraGas>> listarLeituras() async {
    final results = await conn.query(
      'SELECT id, id_dispositivo, id_localizacao, dataHora, foiDetectado, nivelGas '
      'FROM leituragas '
      'ORDER BY dataHora DESC',
    );

    return results.map((row) {
      final id = row[0] as int?;
      final idDisp = row[1] as int;
      final idLoc = row[2] as int?;
      final data = row[3];
      final foi = row[4];
      final nivel = row[5];

      final DateTime dataHora;
      if (data is DateTime) {
        dataHora = data;
      } else {
        dataHora = DateTime.parse(data.toString());
      }

      final bool foiBool;
      if (foi is bool) {
        foiBool = foi;
      } else if (foi is num) {
        foiBool = foi != 0;
      } else {
        foiBool = foi.toString() != '0';
      }

      final double nivelDouble =
          nivel is num ? nivel.toDouble() : double.parse(nivel.toString());

      return LeituraGas(
        id: id,
        idDispositivo: idDisp,
        idLocalizacao: idLoc,
        dataHora: dataHora,
        foiDetectado: foiBool,
        nivelGas: nivelDouble,
      );
    }).toList();
  }

   // === 4. Lista alertas ===
  // O que: retorna alertas cadastrados na tabela `alerta`.
  // Como: SELECT com campos de ID, leitura associada, mensagem, nivel e data/hora.
  // Por que: exibir no menu os eventos de risco registrados pelo sistema.
  Future<List<Alerta>> listarAlertas() async {
    final results = await conn.query(
      'SELECT id, id_leitura, mensagem, nivelGas, dataHora '
      'FROM alerta '
      'ORDER BY dataHora DESC',
    );

    return results.map((row) {
      final id = row[0] as int?;
      final idLeitura = row[1] as int;
      final msg = row[2] as String;
      final nivel = row[3];
      final data = row[4];

      final double nivelDouble =
          nivel is num ? nivel.toDouble() : double.parse(nivel.toString());

      DateTime? dataHora;
      if (data is DateTime) {
        dataHora = data;
      } else if (data != null) {
        dataHora = DateTime.tryParse(data.toString());
      }

      return Alerta(
        id: id,
        idLeitura: idLeitura,
        mensagem: msg,
        nivelGas: nivelDouble,
        dataHora: dataHora,
      );
    }).toList();
  }

  // === 5. Lista historico de uso ===
  // O que: retorna registros de `historicouso` com usuario, acao e data/hora.
  // Como: SELECT ordenado pela data, mapeando para [HistoricoUso].
  // Por que: permitir auditoria das acoes administrativas realizadas.
  Future<List<HistoricoUso>> listarHistoricoUso() async {
    final results = await conn.query(
      'SELECT id, id_usuario, acao, dataHora '
      'FROM historicouso '
      'ORDER BY dataHora DESC',
    );

    return results.map((row) {
      final id = row[0] as int?;
      final idUsuario = row[1] as int;
      final acao = row[2] as String;
      final data = row[3];

      DateTime? dataHora;
      if (data is DateTime) {
        dataHora = data;
      } else if (data != null) {
        dataHora = DateTime.tryParse(data.toString());
      }

      return HistoricoUso(
        id: id,
        idUsuario: idUsuario,
        acao: acao,
        dataHora: dataHora,
      );
    }).toList();
  }
}
