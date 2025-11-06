/// ===============================================================
/// LeituraGas - Modelo da tabela `leituragas`
///
/// O que faz:
/// - Representa uma linha de leitura persistida no MySQL.
///
/// Como faz:
/// - Modelo "burro": apenas campos e construtor, sem logica.
///
/// Por que assim:
/// - Facilita transporte entre Service e DAO mantendo tipagem clara.
///
/// Campos:
/// - id (int?)
/// - idDispositivo (int)
/// - idLocalizacao (int?)
/// - dataHora (DateTime)
/// - foiDetectado (bool)
/// - nivelGas (double)
/// ===============================================================
class LeituraGas {
  final int? id;
  final int idDispositivo;
  final int? idLocalizacao;
  final DateTime dataHora;
  final bool foiDetectado;
  final double nivelGas;

  // === 1. Construtor ===
  LeituraGas({
    this.id,
    required this.idDispositivo,
    this.idLocalizacao,
    required this.dataHora,
    required this.foiDetectado,
    required this.nivelGas,
  });
}

