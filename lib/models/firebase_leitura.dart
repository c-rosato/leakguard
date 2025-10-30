/// Classe modelo que representa a leitura de um sensor MQ-2 registrada no Firebase Realtime Database.
/// Cada leitura contém:
/// - sensorAtivo: se o sensor está ligado ou não
/// - dataHoraLeitura: momento da leitura
/// - gasDetectado: se foi detectado gás
/// - nivelGasPPM: nível atual do gás detectado
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

  /// Construtor de fábrica que cria uma instância a partir de um mapa JSON vindo do Firebase.
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

  /// Retorna uma string formatada para exibir no console.
  @override
  String toString() {
    return 'Ativo: ${sensorAtivo ? "Sim" : "Não"} | '
           'Detectado: ${gasDetectado ? "Sim" : "Não"} | '
           'Nível: ${nivelGasPPM.toStringAsFixed(2)} | '
           'Data/Hora: $dataHoraLeitura';
  }
}
