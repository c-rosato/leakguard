/// ===============================================================
/// Dispositivo - Modelo da tabela `dispositivo`
///
/// O que faz:
/// - Representa um dispositivo cadastrado no MySQL.
///
/// Como faz:
/// - Modelo "burro": somente dados para trafegar entre DAO/Service.
///
/// Por que assim:
/// - Manter responsabilidades separadas e codigo simples.
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

