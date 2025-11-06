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
/// 3. Semear a localizacao padrao e garantir (sob demanda) os dispositivos que chegarem.
/// 4. Ler snapshot inicial do Firebase para exibir o estado atual ao usuario.
/// 5. Iniciar o polling continuo (listenToSensorData) para processar novas leituras.
/// 6. Sincronizar o status `ativo` do dispositivo e armazenar leituras/alertas quando
///    ocorrer a transicao `false -> true`.
/// 7. Manter o processo rodando ate que o usuario digite `sair` no console.
///
/// Observacao:
/// - Toda configuracao acontece em ordem: carrega env -> autentica -> instancia
///   DB -> semeia localizacao -> processa leituras (sementes de dispositivos sao feitas sob demanda).
/// ===============================================================
/// main - Orquestra o fluxo do console
///
/// O que faz:
/// - Inicializa configuracoes, autentica no Firebase e instancia servicos.
/// - Semeia `localizacao` padrao e garante `dispositivo` existente.
/// - Le snapshot inicial e inicia polling continuo do Firebase.
/// - Aplica regras simples: sincroniza `ativo`, persiste leitura quando
///   houve transicao `false -> true` e avalia alerta.
///
/// Como faz:
/// - Usa [AuthService.autenticarAnonimamente] para obter token.
/// - Usa [FirebaseService.getCurrentSensorData] e [FirebaseService.listenToSensorData]
///   para ler dados.
/// - Chama [LocalizacaoService.seedLocalizacaoPadrao] e
///   [DispositivoService.seedDispositivo]/[DispositivoService.sincronizarAtivo].
/// - Converte/insere via [LeituraService.processarLeitura] e avalia com
///   [AlertaService.avaliarERegistrar].
void main() async {
  // === 1. Carrega variaveis de ambiente ===
  // O que: carrega chaves do arquivo `.env`.
  // Como: [DotEnv.load] torna valores acessiveis via `dotenv['CHAVE']`.
  // Por que: centralizar credenciais/URLs sem hardcode.
  final dotenv = DotEnv();
  dotenv.load();

  // === 2. Autenticacao anonima no Firebase ===
  // O que: obter `idToken` para autorizar leitura do Realtime Database.
  // Como: [AuthService.autenticarAnonimamente] usando `FIREBASE_API_KEY` do .env.
  // Por que: compor URLs com `?auth=token` no [FirebaseService].
  final auth = AuthService(dotenv);
  print('Autenticando no Firebase...');
  final token = await auth.autenticarAnonimamente();

  if (token == null) {
    print('Falha na autenticacao. Encerrando...');
    return;
  }
  print('Autenticado com sucesso!');

  // === 3. Inicializa FirebaseService ===
  // O que: cliente REST do Realtime Database.
  // Como: instancia [FirebaseService] com `baseUrl` e `authToken`.
  // Por que: ler snapshot inicial e iniciar polling.
  final firebase = FirebaseService(
    baseUrl: dotenv['FIREBASE_BASE_URL'] ?? '',
    authToken: token,
  );

  // === 3.1. Inicializa DB/DAOs/Services ===
  // O que: montar infraestrutura de banco e regras.
  // Como: 
  // - [DbService.openConnection] sera usado pelos DAOs.
  // - DAOs: [LeituraGasDao], [AlertaDao], [DispositivoDao], [LocalizacaoDao].
  // - Services: [LeituraService], [AlertaService], [DispositivoService], [LocalizacaoService].
  // Por que: separar acesso a dados (DAO) das regras (Service).
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

  // === Seed de localizacao padrao ===
  // O que: garantir localizacao ID=1 disponivel para FKs.
  // Como: [LocalizacaoService.seedLocalizacaoPadrao] -> [LocalizacaoDao.seedPadrao].
  // Por que: dispositivo/leituras referenciam essa FK quando necessario.
  final idLocalizacaoPadrao =
      await localizacaoService.seedLocalizacaoPadrao();

  // === 4. Snapshot inicial do Firebase ===
  // O que: obter estado atual do sensor.
  // Como: [FirebaseService.getCurrentSensorData] e, se houver dado:
  //   - [DispositivoService.seedDispositivo] com `idLocalizacaoPadrao`.
  //   - [DispositivoService.sincronizarAtivo] com base no snapshot.
  // Por que: exibir status e alinhar `ativo` no MySQL.
  final leituraAtual = await firebase.getCurrentSensorData();
  if (leituraAtual != null) {
    await dispositivoService.seedDispositivo(
      idDispositivo: leituraAtual.idDispositivo,
      idLocalizacaoPadrao: idLocalizacaoPadrao,
    );
    await dispositivoService.sincronizarAtivo(
      idDispositivo: leituraAtual.idDispositivo,
      leituraFirebase: leituraAtual,
    );

    if (leituraAtual.gasDetectado) {
      print('Ultima leitura do sensor (detecao de gas): $leituraAtual');
    } else {
      print('Ultima leitura do sensor: $leituraAtual');
      print('Nenhum dado atual com detecao de gas encontrado.');
    }
  } else {
    print('Nenhum dado encontrado no Firebase (no /mq2 vazio).');
  }

  // === 5. Loop de escuta (polling) ===
  // O que: acompanhar mudancas relevantes do sensor.
  // Como: [FirebaseService.listenToSensorData] (3s).
  //   - A cada leitura: seed do dispositivo e sincronizar `ativo`.
  //   - Em transicao `false -> true`: [LeituraService.processarLeitura]
  //     e [AlertaService.avaliarERegistrar].
  // Por que: gravar leituras somente na deteccao.
  print('Escutando leituras do sensor MQ-2 (polling a cada 3 segundos)...\n');

  FirebaseLeitura? ultimaLeituraProcessada;

  // Detalhe do processamento da stream:
  // O que: sincroniza `ativo` e persiste leitura apenas em `false -> true`.
  // Como: calcula `detectouAgora` comparando com `ultimaLeituraProcessada`.
  // Por que: atender a regra didatica do projeto.
  late StreamSubscription<FirebaseLeitura?> subscription;
  subscription = firebase.listenToSensorData(path: '/mq2').listen(
    (leitura) async {
      if (leitura == null) {
        return;
      }

      try {
        await dispositivoService.seedDispositivo(
          idDispositivo: leitura.idDispositivo,
          idLocalizacaoPadrao: idLocalizacaoPadrao,
        );
        await dispositivoService.sincronizarAtivo(
          idDispositivo: leitura.idDispositivo,
          leituraFirebase: leitura,
        );

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

  // === 6. Input do usuario ===
  // O que: permitir encerrar o console digitando 'sair'.
  // Como: stream de stdin (decoder + LineSplitter); cancela streams e `exit(0)`.
  // Por que: finalizar o processo manualmente sem bloquear o loop.
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

  // === 7. Mantem o processo ativo ===
  // O que: impedir encerramento imediato.
  // Como: `Future.delayed` prolongado mantendo o event loop vivo.
  // Por que: console segue rodando ate o usuario encerrar.
  await Future.delayed(const Duration(days: 1));
}
