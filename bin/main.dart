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
import 'package:leakguard_mq2/daos/usuario_dao.dart';
import 'package:leakguard_mq2/daos/historico_uso_dao.dart';
import 'package:leakguard_mq2/services/usuario_service.dart';
import 'package:leakguard_mq2/services/historico_uso_service.dart';
import 'package:leakguard_mq2/daos/menu_read_dao.dart';

/// ===============================================================
/// LeakGuard Console - MQ-2
///
/// Visão geral do fluxo:
/// 1) Carrega o arquivo `.env` e obtém um `idToken` anônimo no Firebase.
/// 2) Cria `DbService`, DAOs e Services que acessam MySQL e Firebase.
/// 3) Garante a existência de uma localização padrão utilizada como FK.
/// 4) Executa um snapshot inicial do estado atual do sensor no Firebase.
/// 5) Inicia o polling contínuo (3s) que sincroniza `ativo`, grava leituras
///    relevantes e gera alertas.
/// 6) Abre o canal de entrada do usuário (`menu` / `sair`), integrando o
///    menu de console sem interromper o polling.
///
/// A orquestração do snapshot e do polling é feita pelo [SensorController].
/// ===============================================================
/// main - ponto de entrada
/// - Configura variáveis de ambiente, autenticação Firebase e serviços.
/// - Semeia localização padrão e inicia snapshot/polling do sensor.
/// - Mantém o processo ativo enquanto o usuário não encerrar o console.
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
  final usuarioDao = UsuarioDao(dbService);
  final historicoUsoDao = HistoricoUsoDao(dbService);

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
  final usuarioService = UsuarioService(usuarioDao: usuarioDao);
  final historicoUsoService =
      HistoricoUsoService(historicoUsoDao: historicoUsoDao);

  // Garante usuarios basicos para o historico de uso
  await usuarioService.seedUsuariosPadrao(dotenv);

  // === Conexao exclusiva para o menu (VIEW) ===
  // Estilo do exemplo mysql_case: uma conexao unica reaproveitada
  // apenas para SELECTs do menu.
  final menuConnection = await dbService.openConnection();
  final menuReadDao = MenuReadDao(menuConnection);

  // === VIEW (menu de console) - estrutura nao bloqueante ===
  // O que: menu acionado pelo usuario via stdin ('menu'), sem interromper polling.
  // Como: maquina de estados consumindo mesmas linhas do stdin, sem bloquear thread.
  // Por que: preparar integracao gradual do VIEW (login/listagens) sem quebrar fluxo.
  final consoleView = ConsoleView(
    dotenv: dotenv,
    dispositivoService: dispositivoService,
    localizacaoService: localizacaoService,
    leituraService: leituraService,
    alertaService: alertaService,
    historicoUsoService: historicoUsoService,
    menuReadDao: menuReadDao,
  );

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
