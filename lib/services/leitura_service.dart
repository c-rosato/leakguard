import 'package:leakguard_mq2/models/firebase_leitura.dart';
import 'package:leakguard_mq2/models/leitura_gas.dart';
import 'package:leakguard_mq2/daos/leitura_gas_dao.dart';

/// ===============================================================
/// LeituraService - Regras de negocio da leitura
///
/// Responsabilidades:
/// - Converter leituras recebidas do Firebase ([FirebaseLeitura]) para o
///   modelo de persistencia [LeituraGas].
/// - Resolver e associar a localizacao vigente do dispositivo a cada leitura.
/// - Persistir a leitura em `leituragas` e devolver o ID gerado.
///
/// Implementacao:
/// - Consulta a localizacao atual do dispositivo via
///   [LeituraGasDao.obterLocalizacaoDoDispositivo].
/// - Monta um [LeituraGas] com data/hora local do console.
/// - Chama [LeituraGasDao.inserir] para gravar a leitura no MySQL.
/// ===============================================================
class LeituraService {
  final LeituraGasDao leituraGasDao;

  // === 1. Construtor ===
  LeituraService({required this.leituraGasDao});

  // === 2. Converte e persiste a leitura; retorna o ID gerado ===
  // O que: transforma a leitura do Firebase em modelo MySQL e insere.
  // Como: busca localizacao no DAO, monta modelo e chama DAO.inserir.
  // Por que: centralizar a regra de conversao e manter o codigo dos DAOs simples.
  Future<int> processarLeitura(FirebaseLeitura leituraFirebase) async {
    final deviceId = leituraFirebase.idDispositivo;
    final idLocalizacao =
        await leituraGasDao.obterLocalizacaoDoDispositivo(idDispositivo: deviceId);

    // Data/Hora: usa hora local do dispositivo (ignora a recebida do Firebase)
    final DateTime dataHora = DateTime.now();

    final leitura = LeituraGas(
      idDispositivo: deviceId,
      idLocalizacao: idLocalizacao,
      dataHora: dataHora,
      foiDetectado: leituraFirebase.gasDetectado,
      nivelGas: leituraFirebase.nivelGasPPM,
    );

    // Quem chama este metodo: `bin/main.dart`, quando detecta transicao
    // `foiDetectado: false -> true`.
    final idGerado = await leituraGasDao.inserir(leitura);
    return idGerado;
  }
}
