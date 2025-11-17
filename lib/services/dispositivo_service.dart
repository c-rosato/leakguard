import 'package:leakguard_mq2/daos/dispositivo_dao.dart';
import 'package:leakguard_mq2/models/firebase_leitura.dart';

/// ===============================================================
/// DispositivoService - Regras simples do dispositivo
///
/// Responsabilidades:
/// - Garantir que dispositivos informados pelo sensor existam na tabela
///   `dispositivo` (seed).
/// - Sincronizar o campo `ativo` conforme o status recebido do Firebase.
/// - Vincular ou alterar a localizacao associada ao dispositivo.
/// - Criar novos dispositivos a partir de acoes administrativas.
///
/// Implementacao:
/// - Encapsula chamadas ao [DispositivoDao] para seed, atualizacao de
///   `ativo`, manutencao de `id_localizacao` e insercao de novos registros.
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

  // === 6. Cria um novo dispositivo (acao administrativa) ===
  Future<int> criarNovoDispositivo({
    required String nome,
    required int idLocalizacao,
  }) async {
    return await dispositivoDao.inserirNovo(
      nome: nome,
      idLocalizacao: idLocalizacao,
    );
  }
}
