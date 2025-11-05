/// ===============================================================
/// LeituraGas - Modelo da tabela `leituragas`
///
/// Funcao principal:
/// - Representar uma linha da tabela `leituragas` do MySQL.
/// - Modelo "burro": apenas campos e construtor.
///
/// Campos:
/// - id (int?)
/// - idDispositivo (int)
/// - dataHora (DateTime)
/// - foiDetectado (bool)
/// - nivelGas (double)
/// ===============================================================
class LeituraGas {
  final int? id;
  final int idDispositivo;
  final DateTime dataHora;
  final bool foiDetectado;
  final double nivelGas;

  // === 1. Construtor ===
  LeituraGas({
    this.id,
    required this.idDispositivo,
    required this.dataHora,
    required this.foiDetectado,
    required this.nivelGas,
  });
}

