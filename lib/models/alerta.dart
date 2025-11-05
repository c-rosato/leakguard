/// ===============================================================
/// Alerta - Modelo da tabela `alerta`
///
/// Funcao principal:
/// - Representar uma linha da tabela `alerta` do MySQL.
/// - Modelo "burro": apenas campos e construtor.
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

