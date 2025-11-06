/// ===============================================================
/// FirebaseLeitura - Modelo de dados do sensor MQ-2
///
/// Objetivo:
/// Representar a leitura que chega do Firebase, com todas as informações
/// necessárias para as regras posteriores (dispositivo, status e nível).
///
/// Cada leitura contem:
/// - idDispositivo (int): identificador informado pelo ESP32.
/// - sensorAtivo (bool)
/// - dataHoraLeitura (String, ISO 8601)
/// - gasDetectado (bool)
/// - nivelGasPPM (double)
/// ===============================================================
class FirebaseLeitura {
  final int idDispositivo;
  final bool sensorAtivo;
  final String dataHoraLeitura;
  final bool gasDetectado;
  final double nivelGasPPM;

  FirebaseLeitura({
    required this.idDispositivo,
    required this.sensorAtivo,
    required this.dataHoraLeitura,
    required this.gasDetectado,
    required this.nivelGasPPM,
  });

  // === 1. Cria instância a partir do JSON retornado pelo Firebase ===
  // O que: fabrica um objeto a partir do mapa JSON recebido.
  // Como: converte tipos tolerando num/String e booleanos (0/1 -> bool).
  // Por que: centralizar o parsing do payload do Firebase.
  factory FirebaseLeitura.fromJson(Map<String, dynamic> json) {
    final id = json['idDispositivo'];
    return FirebaseLeitura(
      idDispositivo: id is num ? id.toInt() : int.tryParse(id.toString()) ?? 1,
      sensorAtivo: json['ativo'] is bool ? json['ativo'] : json['ativo'] == 1,
      dataHoraLeitura: json['dataHora'] as String,
      gasDetectado: json['foiDetectado'] is bool
          ? json['foiDetectado']
          : json['foiDetectado'] == 1,
      nivelGasPPM: (json['nivelGas'] as num).toDouble(),
    );
  }

  // === 2. Representação amigável para o console ===
  // O que: imprime campos principais em formato legivel para debug.
  // Como: monta string com os principais dados da leitura.
  // Por que: facilitar acompanhamento no terminal.
  @override
  String toString() {
    return 'Dispositivo: $idDispositivo | Ativo: ${sensorAtivo ? "Sim" : "Nao"} | '
        'Detectado: ${gasDetectado ? "Sim" : "Nao"} | '
        'Nivel: ${nivelGasPPM.toStringAsFixed(2)} ppm | '
        'Data/Hora: $dataHoraLeitura';
  }
}
