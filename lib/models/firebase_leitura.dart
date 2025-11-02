/// ===============================================================
/// FirebaseLeitura - Modelo de dados do sensor MQ-2
///
/// Função principal:
/// Representar uma leitura armazenada no Firebase Realtime Database,
/// refletindo o estado atual do sensor MQ-2.
///
/// Cada leitura contém:
/// - ativo (bool): se o sensor está ligado
/// - dataHora (String, ISO8601): momento da leitura
/// - foiDetectado (bool): se foi detectado gás
/// - nivelGas (double): nível de gás em PPM
///
/// Este modelo é usado para conversão JSON → Objeto Dart.
/// ===============================================================
class FirebaseLeitura {
  final bool sensorAtivo;
  final String dataHoraLeitura;
  final bool gasDetectado;
  final double nivelGasPPM;

  FirebaseLeitura({
    required this.sensorAtivo,
    required this.dataHoraLeitura,
    required this.gasDetectado,
    required this.nivelGasPPM,
  });

  // === 1. Cria instância a partir de JSON retornado pelo Firebase ===
  //
  // Faz tratamento de tipo para valores vindos como int ou bool.
  factory FirebaseLeitura.fromJson(Map<String, dynamic> json) {
    return FirebaseLeitura(
      sensorAtivo: json['ativo'] is bool ? json['ativo'] : json['ativo'] == 1,
      dataHoraLeitura: json['dataHora'] as String,
      gasDetectado: json['foiDetectado'] is bool
          ? json['foiDetectado']
          : json['foiDetectado'] == 1,
      nivelGasPPM: (json['nivelGas'] as num).toDouble(),
    );
  }

  // === 2. Retorna representação legível para o console ===
  //
  // Formato:
  // Ativo: Sim | Detectado: Não | Nível: 145.32 ppm | Data/Hora: 2025-11-02T21:40:00
  @override
  String toString() {
    return 'Ativo: ${sensorAtivo ? "Sim" : "Não"} | '
        'Detectado: ${gasDetectado ? "Sim" : "Não"} | '
        'Nível: ${nivelGasPPM.toStringAsFixed(2)} ppm | '
        'Data/Hora: $dataHoraLeitura';
  }
}
