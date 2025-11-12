import 'package:leakguard_mq2/daos/localizacao_dao.dart';
import 'package:leakguard_mq2/models/localizacao.dart';

/// ===============================================================
/// LocalizacaoService - Regras simples para `localizacao`
///
/// O que faz:
/// - Orquestra listagem, criação e seed da localização padrão.
///
/// Como faz:
/// - Encapsula chamadas ao [LocalizacaoDao] e retorna modelos prontos para uso.
/// ===============================================================
class LocalizacaoService {
  final LocalizacaoDao localizacaoDao;

  // === 1. Construtor ===
  LocalizacaoService({required this.localizacaoDao});

  // === 2. Lista localizações ordenadas pelo nome ===
  // O que: devolve todas as localizações existentes.
  // Como: delega ao DAO e converte linhas em [Localizacao].
  Future<List<Localizacao>> listarLocalizacoes() async {
    return await localizacaoDao.listarTodas();
  }

  // === 3. Cria uma nova localização ===
  // O que: insere uma localização e retorna o ID gerado.
  // Como: delega para [LocalizacaoDao.inserir].
  Future<int> criarLocalizacao(Localizacao localizacao) async {
    return await localizacaoDao.inserir(localizacao);
  }

  // === 4. Garante localização padrão e retorna o ID ===
  // O que: assegura a existência da localização padrão (ID fixo = 1).
  // Como: tenta reutilizar por nome; se não houver, cria via [LocalizacaoDao.seedPadrao].
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
