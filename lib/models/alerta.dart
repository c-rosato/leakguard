/// ===============================================================
/// Alerta - Modelo da tabela `alerta`
///
/// O que faz:
/// - Representa um alerta gerado quando nivel de gas excede o limiar.
///
/// Como faz:
/// - Modelo "burro": armazena dados para persistencia via DAO.
///
/// Por que assim:
/// - Separar camadas e manter o foco da regra no service.
///
/// Campos:
/// - id (int?)
/// - idLeitura (int)
/// - mensagem (String)
/// - nivelGas (double)
/// - dataHora (DateTime?)
/// ===============================================================
class Alerta {
  final int? id;
  final int idLeitura;
  final String mensagem;
  final double nivelGas;
  final DateTime? dataHora;

  // === 1. Construtor ===
  Alerta({
    this.id,
    required this.idLeitura,
    required this.mensagem,
    required this.nivelGas,
    this.dataHora,
  });
}

