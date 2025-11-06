import 'package:leakguard_mq2/daos/localizacao_dao.dart';
import 'package:leakguard_mq2/models/localizacao.dart';

/// ===============================================================
/// LocalizacaoService - Regras simples para `localizacao`
///
/// O que faz:
/// - Orquestra listagem/criacao/seed de localizacoes.
///
/// Como faz:
/// - Encapsula chamadas ao [LocalizacaoDao] e mapeia resultados para modelos.
///
/// Por que assim:
/// - Manter o `main.dart` simples e a regra de seed centralizada aqui.
/// ===============================================================
class LocalizacaoService {
  final LocalizacaoDao localizacaoDao;

  // === 1. Construtor ===
  LocalizacaoService({required this.localizacaoDao});

  // === 2. Lista localizacoes ordenadas pelo nome ===
  // O que: devolve todas as localizacoes para exibicao/selecionar.
  // Como: SELECT direto; converte linhas em [Localizacao].
  // Por que: oferecer dados para menus e validacoes simples.
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
  // O que: insere uma localizacao.
  // Como: delega para [LocalizacaoDao.inserir].
  // Por que: centralizar possiveis validacoes futuras.
  Future<int> criarLocalizacao(Localizacao localizacao) async {
    return await localizacaoDao.inserir(localizacao);
  }

  // === 4. Garante localizacao padrao e retorna o ID ===
  // O que: assegura que a localizacao padrao exista (ID fixo = 1).
  // Como: tenta reutilizar por nome; se nao houver, chama [LocalizacaoDao.seedPadrao].
  // Por que: para que dispositivos e leituras possam referenciar um ID conhecido.
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
