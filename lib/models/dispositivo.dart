/// ===============================================================
/// Dispositivo - Modelo da tabela `dispositivo`
///
/// Funcao principal:
/// - Representar uma linha da tabela `dispositivo` do MySQL.
/// - Modelo "burro": apenas campos e construtor.
///
/// Campos:
/// - id (int?)
/// - nome (String)
/// - ativo (bool)
/// - idLocalizacao (int?)
/// ===============================================================
class Dispositivo {
  final int? id;
  final String nome;
  final bool ativo;
  final int? idLocalizacao;

  // === 1. Construtor ===
  Dispositivo({
    this.id,
    required this.nome,
    required this.ativo,
    this.idLocalizacao,
  });
}

