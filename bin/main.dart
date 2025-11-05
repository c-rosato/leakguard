import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

/// ===============================================================
/// LeakGuard Console - MQ-2 (versao com polling)
///
/// Funcoes principais (ordem cronologica):
/// 1. Carregar configuracoes (.env) e autenticar no Firebase via [AuthService].
/// 2. Montar infraestrutura de banco (DbService + DAOs) e instanciar os services.
/// 3. Semear localizacao padrao e dispositivo (1:1) garantindo integridade da FK.
/// 4. Ler snapshot inicial do Firebase para exibir o estado atual ao usuario.
/// 5. Iniciar o polling continuo (listenToSensorData) para processar novas leituras.
/// 6. Sincronizar o status `ativo` do dispositivo e armazenar leituras/alertas quando
///    ocorrer a transicao `false -> true`.
/// 7. Manter o processo rodando ate que o usuario digite `sair` no console.
///
/// Observacao:
/// - Toda configuracao acontece em ordem: carrega env -> autentica -> instancia
///   DB -> semeia localizacao -> semeia dispositivo -> inicia leituras.
/// ===============================================================
void main() async {
  // === 1. Carrega variaveis de ambiente ===
  // DotEnv le o arquivo .env (na pasta bin/) e deixa chaves acessiveis via [].
  final dotenv = DotEnv();
  dotenv.load();

  // === 2. Autenticacao anonima no Firebase ===
  // AuthService usa FIREBASE_API_KEY para obter um idToken temporario.
  final auth = AuthService(dotenv);
  print('Autenticando no Firebase...');
  final token = await auth.autenticarAnonimamente();

  if (token == null) {
    print('Falha na autenticacao. Encerrando...');
    return;
  }
  print('Autenticado com sucesso!');

  // === 3. Inicializa o servico de comunicacao com o Firebase ===
  // FirebaseService encapsula o polling HTTP (Realtime Database REST API).
  final firebase = FirebaseService(
    baseUrl: dotenv['FIREBASE_BASE_URL'] ?? '',
    authToken: token,
  );

  // === 3.1. Inicializa DB/DAOs/Services e faz seed do dispositivo ===
  // Etapas de infraestrutura:
  // - DbService: leitura de host/porta/usuario/senha do .env e abre conexoes on-demand.
  // - DAOs: recebem DbService e executam SQLs especificos (leitura/alerta/dispositivo/localizacao).
  // - Services: encapsulam a "regra didatica" do projeto (ex.: conversao da leitura).
  final dbService = DbService(dotenv);
  final leituraGasDao = LeituraGasDao(dbService);
  final alertaDao = AlertaDao(dbService);
  final dispositivoDao = DispositivoDao(dbService);
  final localizacaoDao = LocalizacaoDao(dbService);

  final leituraService = LeituraService(
    dotenv: dotenv,
    leituraGasDao: leituraGasDao,
  );
  final alertaService = AlertaService(alertaDao: alertaDao);
  final dispositivoService = DispositivoService(
    dotenv: dotenv,
    dispositivoDao: dispositivoDao,
  );
  final localizacaoService = LocalizacaoService(
    localizacaoDao: localizacaoDao,
  );

  // Semear localizacao padrao antes do dispositivo (garante FK disponivel)
  // LocalizacaoService.seedLocalizacaoPadrao -> LocalizacaoDao.seedPadrao (ID fixo = 1).
  // Em seguida DispositivoService.seedDispositivo vincula o dispositivo 1 nessa localizacao.
  final idLocalizacaoPadrao =
      await localizacaoService.seedLocalizacaoPadrao();
  await dispositivoService.seedDispositivo(
    idLocalizacaoPadrao: idLocalizacaoPadrao,
  );

  // === 4. Faz a leitura inicial (snapshot atual do no /mq2) ===
  // Objetivos:
  // - Mostrar no console a ultima leitura existente (caso haja).
  // - Sincronizar imediatamente o campo `ativo` do dispositivo no MySQL.
  final leituraAtual = await firebase.getCurrentSensorData();
  if (leituraAtual != null) {
    await dispositivoService.sincronizarAtivo(leituraAtual);

    if (leituraAtual.gasDetectado) {
      print('Ultima leitura do sensor (detecao de gas): $leituraAtual');
    } else {
      print('Ultima leitura do sensor: $leituraAtual');
      print('Nenhum dado atual com detecao de gas encontrado.');
    }
  } else {
    print('Nenhum dado encontrado no Firebase (no /mq2 vazio).');
  }

  // === 5. Inicia o loop de escuta (polling continuo) ===
  // A partir daqui o console fica "escutando" de segundo plano ate o usuario encerrar.
  print('Escutando leituras do sensor MQ-2 (polling a cada 3 segundos)...\n');

  FirebaseLeitura? ultimaLeituraProcessada;

  // A stream a seguir roda em paralelo, emitindo leituras novas conforme regras:
  // - Cada ciclo sincroniza status do dispositivo (ativo/inativo).
  // - So grava no MySQL quando ocorre a transicao `false -> true` (detecao de gas).
  late StreamSubscription<FirebaseLeitura?> subscription;
  subscription = firebase.listenToSensorData(path: '/mq2').listen(
    (leitura) async {
      if (leitura == null) {
        return;
      }

      try {
        await dispositivoService.sincronizarAtivo(leitura);

        if (ultimaLeituraProcessada == null) {
          ultimaLeituraProcessada = leitura;
          return; // ignora primeiro evento apenas para inicializar estado
        }

        final detectouAgora = !ultimaLeituraProcessada!.gasDetectado &&
            leitura.gasDetectado;

        if (detectouAgora) {
          print('Nova leitura recebida: $leitura');

          final leituraId = await leituraService.processarLeitura(leitura);
          await alertaService.avaliarERegistrar(
            leituraFirebase: leitura,
            idLeitura: leituraId,
          );
        }

        ultimaLeituraProcessada = leitura;
      } catch (e) {
        print('Erro ao processar leitura e regras: $e');
      }
    },
    onError: (error) => print('Erro ao consultar Firebase: $error'),
    cancelOnError: false,
  );

  // === 6. Escuta input do usuario sem bloquear o loop principal ===
  // Permite encerrar o programa digitando "sair" no console.
  // stdinSubscription fica responsavel por comandos de usuario (simples e nao bloqueante).
  late StreamSubscription<String> stdinSubscription;
  stdinSubscription = stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((input) async {
    if (input.toLowerCase() == 'sair') {
      print('Encerrando o console...');
      subscription.cancel();
      stdinSubscription.cancel();
      Future.microtask(() => exit(0)); // finaliza o programa
    }
  });

  // === 7. Mantem o programa ativo "em espera" (nao finaliza o processo) ===
  await Future.delayed(const Duration(days: 1));
}
