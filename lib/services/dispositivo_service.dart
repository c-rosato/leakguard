import 'package:leakguard_mq2/daos/dispositivo_dao.dart';
import 'package:leakguard_mq2/models/firebase_leitura.dart';

/// ===============================================================
/// DispositivoService - Regras simples do dispositivo
///
/// O que faz:
/// - Garante existencia do dispositivo, sincroniza `ativo` e gerencia a FK de localizacao.
///
/// Como faz:
/// - Encapsula chamadas ao [DispositivoDao] para seed, update de `ativo` e `id_localizacao`.
///
/// Por que assim:
/// - Centraliza regras simples, deixa o DAO focado no SQL e o `main.dart` limpo.
/// ===============================================================
class DispositivoService {
  final DispositivoDao dispositivoDao;

  // === 1. Construtor ===
  DispositivoService({required this.dispositivoDao});

  // === 2. Garante o dispositivo no banco (seed) ===
  // O que: cria se nao existir, sem duplicar.
  // Como: delega para [DispositivoDao.seedSeNecessario].
  // Por que: permitir loop idempotente no inicio e a cada leitura.
  Future<void> seedDispositivo({
    required int idDispositivo,
    int? idLocalizacaoPadrao,
    String nomePadrao = 'ESP32 MQ-2',
  }) async {
    await dispositivoDao.seedSeNecessario(
      idDispositivo: idDispositivo,
      nomePadrao: nomePadrao,
      idLocalizacao: idLocalizacaoPadrao,
    );
  }

  // === 3. Atualiza o campo `ativo` conforme Firebase ===
  // O que: reflete se o sensor esta operacional ou nao.
  // Como: [DispositivoDao.atualizarAtivo] com valor vindo do Firebase.
  // Por que: permitir auditoria/BI do status do equipamento.
  Future<void> sincronizarAtivo({
    required int idDispositivo,
    required FirebaseLeitura leituraFirebase,
  }) async {
    await dispositivoDao.atualizarAtivo(
      idDispositivo: idDispositivo,
      ativo: leituraFirebase.sensorAtivo,
    );
  }

  // === 4. Vincula o dispositivo a uma localizacao ===
  // O que: define/remover a FK de localizacao do dispositivo.
  // Como: delega para [DispositivoDao.atualizarLocalizacao].
  // Por que: mudar a alocacao fisica conforme necessidade.
  Future<void> vincularLocalizacao({
    required int idDispositivo,
    required int? idLocalizacao,
  }) async {
    await dispositivoDao.atualizarLocalizacao(
      idDispositivo: idDispositivo,
      idLocalizacao: idLocalizacao,
    );
  }
}
