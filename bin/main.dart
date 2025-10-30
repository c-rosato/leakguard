import 'dart:async';
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:leakguard_mq2/services/auth_service.dart';
import 'package:leakguard_mq2/services/firebase_stream_service.dart';
import 'package:leakguard_mq2/models/firebase_leitura.dart';

/// Programa principal (console) que:
/// - Carrega variáveis de ambiente do arquivo `.env`
/// - Autentica anonimamente no Firebase
/// - Conecta ao Realtime Database
/// - Escuta as leituras do sensor MQ-2 em tempo real
/// - Exibe as leituras no console
/// - Permite encerrar manualmente digitando "sair"
void main() async {
  // Cria e carrega dotenv
  final dotenv = DotEnv();
  dotenv.load(); // carrega o arquivo .env

  // Cria o serviço de autenticação, passando dotenv
  final auth = AuthService(dotenv);

  print('Autenticando no Firebase...');
  final token = await auth.autenticarAnonimamente();

  if (token == null) {
    print('Falha na autenticação. Encerrando...');
    return;
  }

  print('Autenticado com sucesso!');

  // Cria o serviço de stream Firebase, passando token e dotenv
  final firebase = FirebaseStreamService(token, dotenv);

  // Ler o estado atual do sensor assim que inicia
  // Permite ver o valor atual do Realtime Database antes de começar a escutar alterações
  final leituraAtual = await firebase.getCurrentSensorData();
  if (leituraAtual != null) {
    print('Última leitura do sensor: $leituraAtual');
    // TODO: aplicar regras de negócio e salvar no MySQL
  } else {
    print('Nenhum dado atual encontrado.');
  }

  print('Escutando leituras do sensor MQ-2 em tempo real...\n');

  // Cria uma assinatura do stream para poder cancelar se necessário
  late StreamSubscription<FirebaseLeitura?> subscription;

  subscription = firebase.listenToSensorData(path: '/mq2').listen(
    (leitura) {
      if (leitura != null) {
        print('Nova leitura recebida: $leitura');
        // TODO: aplicar regras de negócio e salvar no MySQL
      }
    },
    onError: (error) => print('Erro no stream do Firebase: $error'),
    cancelOnError: true,
  );

  // Permite encerrar manualmente digitando "sair"
  print('Digite "sair" e pressione Enter para encerrar o console:');
  while (true) {
    final input = stdin.readLineSync();
    if (input != null && input.toLowerCase() == 'sair') {
      print('Encerrando o console...');
      await subscription.cancel(); // cancela a escuta do stream
      exit(0); // garante que o programa termina completamente
    }
  }
}
