import 'dart:async';
import 'package:dotenv/dotenv.dart';
import 'package:leakguard_mq2/services/auth_service.dart';
import 'package:leakguard_mq2/services/firebase_service.dart';
import 'package:leakguard_mq2/models/firebase_leitura.dart';
import 'package:leakguard_mq2/services/db_service.dart';
import 'package:leakguard_mq2/services/leitura_service.dart';
import 'package:leakguard_mq2/services/alerta_service.dart';
import 'package:leakguard_mq2/services/dispositivo_service.dart';
import 'package:leakguard_mq2/services/localizacao_service.dart';
import 'package:leakguard_mq2/daos/leitura_gas_dao.dart';
import 'package:leakguard_mq2/daos/alerta_dao.dart';
import 'package:leakguard_mq2/daos/dispositivo_dao.dart';
import 'package:leakguard_mq2/daos/localizacao_dao.dart';
import 'package:leakguard_mq2/views/console_view.dart';
import 'package:leakguard_mq2/controllers/sensor_controller.dart';
import 'package:leakguard_mq2/controllers/input_controller.dart';

/// ===============================================================
/// LeakGuard Console - MQ-2
///
/// Resumo do fluxo:
/// 1) Carrega .env e autentica no Firebase.
/// 2) Instancia DB, DAOs e Services.
/// 3) Semeia localizacao padrao (FK base).
/// 4) Snapshot inicial do Firebase (estado atual).
/// 5) Polling continuo (3s) e processamento: sincroniza `ativo`,
///    persiste em transicao `false -> true` e avalia alerta.
/// 6) Entrada do usuario: `menu` e `sair`.
///
/// Nota: Snapshot e polling foram delegados ao SensorController
/// ===============================================================
/// main - ponto de entrada
/// - Inicializa configuracoes e dependencias.
/// - Semeia localizacao padrao e delega snapshot/polling ao controller.
/// - Mantem o console rodando ate `sair`.
void main() async {
  // === 1. Carrega variaveis de ambiente (.env) ===
  // Torna chaves acessiveis via `dotenv['CHAVE']`.
  final dotenv = DotEnv();
  dotenv.load();

  // === 2. Autenticacao anonima no Firebase ===
  // Obtem idToken para autorizar acesso ao Realtime Database.
  final auth = AuthService(dotenv);
  print('Autenticando no Firebase...');
  final token = await auth.autenticarAnonimamente();

  if (token == null) {
    print('Falha na autenticacao. Encerrando...');
    return;
  }
  print('Autenticado com sucesso!');

  // === 3. Inicializa FirebaseService ===
  // Cliente REST do Realtime Database (baseUrl + token).
  final firebase = FirebaseService(
    baseUrl: dotenv['FIREBASE_BASE_URL'] ?? '',
    authToken: token,
  );

  // === 3.1. Inicializa DB/DAOs/Services ===
  // Camadas: DbService -> DAOs -> Services (regras simples).
  final dbService = DbService(dotenv);
  final leituraGasDao = LeituraGasDao(dbService);
  final alertaDao = AlertaDao(dbService);
  final dispositivoDao = DispositivoDao(dbService);
  final localizacaoDao = LocalizacaoDao(dbService);

  final leituraService = LeituraService(
    leituraGasDao: leituraGasDao,
  );
  final alertaService = AlertaService(alertaDao: alertaDao);
  final dispositivoService = DispositivoService(
    dispositivoDao: dispositivoDao,
  );
  final localizacaoService = LocalizacaoService(
    localizacaoDao: localizacaoDao,
  );

  // === VIEW (menu de console) - estrutura nao bloqueante ===
  // O que: menu acionado pelo usuario via stdin ('menu'), sem interromper polling.
  // Como: maquina de estados consumindo mesmas linhas do stdin, sem bloquear thread.
  // Por que: preparar integracao gradual do VIEW (login/listagens) sem quebrar fluxo.
  final consoleView = ConsoleView(dotenv);

  // === Seed de localizacao padrao ===
  // O que: garantir localizacao ID=1 disponivel para FKs.
  // Como: LocalizacaoService.seedLocalizacaoPadrao -> LocalizacaoDao.seedPadrao.
  // Por que: dispositivo/leituras referenciam essa FK quando necessario.
  final idLocalizacaoPadrao =
      await localizacaoService.seedLocalizacaoPadrao();

  // === 4. Snapshot inicial do Firebase ===
  // O que: obter estado atual do sensor.
  // Como: delega para SensorController.processarSnapshotInicial com mesma logica.
  // Por que: exibir status e alinhar `ativo` no MySQL.
  final sensorController = SensorController(
    firebase: firebase,
    dispositivoService: dispositivoService,
    leituraService: leituraService,
    alertaService: alertaService,
  );
  await sensorController.processarSnapshotInicial(
    idLocalizacaoPadrao: idLocalizacaoPadrao,
  );

  // === 5. Loop de escuta (polling) ===
  // O que: acompanhar mudancas relevantes do sensor.
  // Como: delega para SensorController.iniciarPolling (3s) com a mesma regra.
  // Por que: gravar leituras somente na deteccao.
  final StreamSubscription<FirebaseLeitura?> subscription = sensorController.iniciarPolling(
    idLocalizacaoPadrao: idLocalizacaoPadrao,
    path: '/mq2',
  );

  // === 6. Input do usuario ===
  // O que: permitir encerrar o console digitando 'sair'.
  // Como: delega para InputController.iniciar com mesma logica de roteamento.
  // Por que: finalizar o processo manualmente sem bloquear o loop.
  const inputController = InputController();
  inputController.iniciar(
    consoleView: consoleView,
    sensorSubscription: subscription,
  );

  // === 7. Mantem o processo ativo ===
  // O que: impedir encerramento imediato.
  // Como: Future.delayed prolongado mantendo o event loop vivo.
  // Por que: console segue rodando ate o usuario encerrar.
  await Future.delayed(const Duration(days: 1));
}
