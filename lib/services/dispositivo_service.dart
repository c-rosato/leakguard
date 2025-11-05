import 'package:dotenv/dotenv.dart';
import 'package:leakguard_mq2/daos/dispositivo_dao.dart';
import 'package:leakguard_mq2/models/firebase_leitura.dart';

/// ===============================================================
/// DispositivoService - Regras simples do dispositivo
///
/// O que esta classe faz:
/// - Recebe a instancia de [DotEnv] (para descobrir o DEVICE_ID) e
///   instancia de [DispositivoDao] (responsavel pelo MySQL).
/// - Garante que o dispositivo unico (ESP32 MQ-2) sempre exista no banco.
/// - Mantem o campo `ativo` sincronizado com a leitura do Firebase.
/// - Atualiza a chave estrangeira `id_localizacao` quando necessario.
///
/// Observacao:
/// - O projeto possui apenas 1 dispositivo. O ID vem do .env (DEVICE_ID),
///   padrao 1 se nao definido. Todas as operacoes usam esse ID fixo.
/// ===============================================================
class DispositivoService {
  final DotEnv dotenv;
  final DispositivoDao dispositivoDao;

  // === 1. Construtor ===
  //
  // Recebe:
  // - [DotEnv] carregado no main (ja com as variaveis do arquivo .env).
  // - [DispositivoDao] instanciado no main com o mesmo DbService.
  DispositivoService({required this.dotenv, required this.dispositivoDao});

  // === 2. Garante o dispositivo no banco (seed) ===
  //
  // Como funciona:
  // - Lê o DEVICE_ID do .env (ou assume 1).
  // - Invoca `DispositivoDao.seedSeNecessario`, que faz o INSERT com
  //   ON DUPLICATE KEY UPDATE, incluindo a localizacao padrão.
  // - Usado logo no start do main para garantir dados mínimos.
  Future<void> seedDispositivo({int? idLocalizacaoPadrao}) async {
    final deviceId = int.tryParse(dotenv['DEVICE_ID'] ?? '1') ?? 1;
    await dispositivoDao.seedSeNecessario(
      idDispositivo: deviceId,
      idLocalizacao: idLocalizacaoPadrao,
    );
  }

  // === 3. Atualiza o campo `ativo` conforme Firebase ===
  //
  // Como funciona:
  // - Recebe a ultima [FirebaseLeitura] do polling.
  // - Extrai o DEVICE_ID.
  // - Chama `DispositivoDao.atualizarAtivo` para refletir o status no MySQL.
  // - Rodado em cada iteracao da stream, independente de deteccao de gas.
  Future<void> sincronizarAtivo(FirebaseLeitura leituraFirebase) async {
    final deviceId = int.tryParse(dotenv['DEVICE_ID'] ?? '1') ?? 1;
    await dispositivoDao.atualizarAtivo(
      idDispositivo: deviceId,
      ativo: leituraFirebase.sensorAtivo,
    );
  }

  // === 4. Vincula o dispositivo a uma localizacao ===
  //
  // Como funciona:
  // - Recebe o ID de uma localizacao (ou null se quiser remover).
  // - Usa o mesmo DEVICE_ID e repassa para `DispositivoDao.atualizarLocalizacao`.
  // - Esse metodo e usado tanto na semente inicial quanto no menu futuro.
  Future<void> vincularLocalizacao(int? idLocalizacao) async {
    final deviceId = int.tryParse(dotenv['DEVICE_ID'] ?? '1') ?? 1;
    await dispositivoDao.atualizarLocalizacao(
      idDispositivo: deviceId,
      idLocalizacao: idLocalizacao,
    );
  }
}
