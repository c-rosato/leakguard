/// ===============================================================
/// Localizacao - Modelo da tabela `localizacao`
///
/// Funcao principal:
/// - Representar uma linha da tabela `localizacao`.
/// - Modelo "burro": apenas campos e construtor.
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
