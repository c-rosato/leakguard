import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:leakguard_mq2/services/auth_service.dart';
import 'package:leakguard_mq2/services/firebase_service.dart';
import 'package:leakguard_mq2/models/firebase_leitura.dart';

/// ===============================================================
/// LeakGuard Console - MQ-2 (versão com polling)
///
/// Funções principais:
/// - Autenticar anonimamente no Firebase
/// - Obter e exibir leituras em tempo real do sensor MQ-2 (via Firebase)
/// - Realizar polling periódico a cada 3 segundos
/// - Exibir novas leituras somente quando `foiDetectado` muda de false → true
/// - Permitir encerramento seguro digitando "sair"
///
/// Observação:
/// A comunicação é feita com o nó `/mq2` do Realtime Database,
/// onde o ESP32 atualiza as informações do sensor a cada 5 segundos.
/// ===============================================================
void main() async {
  // === 1. Carrega variáveis de ambiente ===
  final dotenv = DotEnv();
  dotenv.load();

  // === 2. Autenticação anônima no Firebase ===
  final auth = AuthService(dotenv);
  print('Autenticando no Firebase...');
  final token = await auth.autenticarAnonimamente();

  if (token == null) {
    print('Falha na autenticação. Encerrando...');
    return;
  }
  print('Autenticado com sucesso!');

  // === 3. Inicializa o serviço de comunicação com o Firebase ===
  final firebase = FirebaseService(
    baseUrl: dotenv['FIREBASE_BASE_URL'] ?? '',
    authToken: token,
  );

  // === 4. Faz a leitura inicial (snapshot atual do nó /mq2) ===
  final leituraAtual = await firebase.getCurrentSensorData();
  if (leituraAtual != null && leituraAtual.gasDetectado) {
    print('Última leitura do sensor (detecção de gás): $leituraAtual');
  } else {
    print('Nenhum dado atual com detecção de gás encontrado.');
  }

  // === 5. Inicia o loop de escuta (polling contínuo) ===
  print('Escutando leituras do sensor MQ-2 (polling a cada 3 segundos)...\n');

  // A stream a seguir roda em paralelo, emitindo leituras novas apenas quando houver mudança
  late StreamSubscription<FirebaseLeitura?> subscription;
  subscription = firebase.listenToSensorData(path: '/mq2').listen(
    (leitura) {
      if (leitura != null) {
        print('Nova leitura recebida: $leitura');
      }
    },
    onError: (error) => print('Erro ao consultar Firebase: $error'),
    cancelOnError: false,
  );

  // === 6. Escuta input do usuário sem bloquear o loop principal ===
  // Permite encerrar o programa digitando "sair" no console.
  late StreamSubscription<String> stdinSubscription;
  stdinSubscription = stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((input) async {
    if (input.toLowerCase() == 'sair') {
      print('Encerrando o console...');
      await subscription.cancel();       // cancela a stream do Firebase
      await stdinSubscription.cancel();  // cancela a leitura do stdin
      exit(0);                           // finaliza o programa
    }
  });

  // === 7. Mantém o programa ativo "em espera" (não finaliza o processo) ===
  await Future.delayed(const Duration(days: 1));
}
