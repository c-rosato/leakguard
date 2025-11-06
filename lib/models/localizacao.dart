/// ===============================================================
/// Localizacao - Modelo da tabela `localizacao`
///
/// O que faz:
/// - Representa um local fisico cadastrado para alocar dispositivos.
///
/// Como faz:
/// - Modelo "burro": somente campos e construtor.
///
/// Por que assim:
/// - Simples e adequado ao foco didatico do projeto.
/// ===============================================================
class Localizacao {
  final int? id;
  final String nomeLocal;
  final String? descricao;

  // === 1. Construtor ===
  Localizacao({
    this.id,
    required this.nomeLocal,
    this.descricao,
  });
}
