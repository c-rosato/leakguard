import 'package:dotenv/dotenv.dart';
import 'package:leakguard_mq2/models/firebase_leitura.dart';
import 'package:leakguard_mq2/models/leitura_gas.dart';
import 'package:leakguard_mq2/daos/leitura_gas_dao.dart';

/// ===============================================================
/// LeituraService - Regras de negocio da leitura
///
/// Funcoes principais:
/// - Converter FirebaseLeitura -> LeituraGas (modelo MySQL)
/// - Inserir a leitura via DAO e retornar o ID
///
/// Observacao:
/// - O projeto usa apenas 1 dispositivo. O ID vem do .env (DEVICE_ID),
///   mas mantemos o padrao "1" se nao estiver definido.
/// ===============================================================
class LeituraService {
  final DotEnv dotenv;
  final LeituraGasDao leituraGasDao;

  // === 1. Construtor ===
  LeituraService({required this.dotenv, required this.leituraGasDao});

  // === 2. Converte e persiste a leitura; retorna o ID gerado ===
  Future<int> processarLeitura(FirebaseLeitura leituraFirebase) async {
    final deviceId = int.tryParse(dotenv['DEVICE_ID'] ?? '1') ?? 1;

    // Data/Hora: usa hora local do dispositivo (ignora a recebida do Firebase)
    final DateTime dataHora = DateTime.now();

    final leitura = LeituraGas(
      idDispositivo: deviceId,
      dataHora: dataHora,
      foiDetectado: leituraFirebase.gasDetectado,
      nivelGas: leituraFirebase.nivelGasPPM,
    );

    final idGerado = await leituraGasDao.inserir(leitura);
    return idGerado;
  }
}
