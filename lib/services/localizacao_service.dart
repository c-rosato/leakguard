import 'package:leakguard_mq2/daos/localizacao_dao.dart';
import 'package:leakguard_mq2/models/localizacao.dart';

/// ===============================================================
/// LocalizacaoService - Regras simples para `localizacao`
///
/// Reponsabilidades:
/// - Servir como "ponte" entre o console/menu e o [LocalizacaoDao].
/// - Listar localizacoes ja cadastradas (para exibicao ou escolha).
/// - Criar novas entradas com um unico metodo simples.
/// - Garantir que exista uma localizacao padrao (ID=1) antes do seed do dispositivo.
/// ===============================================================
class LocalizacaoService {
  final LocalizacaoDao localizacaoDao;

  // === 1. Construtor ===
  LocalizacaoService({required this.localizacaoDao});

  // === 2. Lista localizacoes ordenadas pelo nome ===
  Future<List<Localizacao>> listarLocalizacoes() async {
    final conn = await localizacaoDao.dbService.openConnection();

    try {
      final results = await conn.query(
        'SELECT id, nome_local, descricao FROM localizacao ORDER BY nome_local',
      );

      return results
          .map((row) => Localizacao(
                id: row['id'] as int?,
                nomeLocal: row['nome_local'] as String,
                descricao: row['descricao'] as String?,
              ))
          .toList();
    } finally {
      await conn.close();
    }
  }

  // === 3. Cria uma nova localizacao ===
  //
  // Apenas delega a chamada para o DAO. Manter esta camada permite
  // evoluir regras simples no futuro (ex.: validar campos) sem alterar o menu.
  Future<int> criarLocalizacao(Localizacao localizacao) async {
    return await localizacaoDao.inserir(localizacao);
  }

  // === 4. Garante localizacao padrao e retorna o ID ===
  //
  // Estrategia:
  // 1. Reutiliza qualquer localizacao existente com o nome padrao
  //    (isso evita re-inserir quando o banco ja possui o valor).
  // 2. Caso nao exista, delega ao DAO um seed com ID fixo usando
  //    INSERT ... ON DUPLICATE KEY UPDATE (mantem idempotencia).
  Future<int> seedLocalizacaoPadrao() async {
    const nomePadrao = 'Laboratorio Geral';
    const descricaoPadrao = 'Localizacao padrao do dispositivo';
    const idPadrao = 1;

    final existentes = await listarLocalizacoes();
    for (final loc in existentes) {
      if (loc.nomeLocal == nomePadrao && loc.id != null) {
        return loc.id!;
      }
    }

    return await localizacaoDao.seedPadrao(
      idLocalizacao: idPadrao,
      nomePadrao: nomePadrao,
      descricaoPadrao: descricaoPadrao,
    );
  }
}
