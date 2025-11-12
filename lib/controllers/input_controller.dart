import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:leakguard_mq2/views/console_view.dart';

/// ===============================================================
/// InputController - Gerencia stdin e integra com a ConsoleView
///
/// Objetivo:
/// - Gerenciar a leitura do stdin e o roteamento de comandos para a camada
///   de visualização.
///
/// Como faz:
/// - Assina stdin, decodifica linhas e normaliza a entrada.
/// - Interpreta comandos globais: `sair` (cancela assinaturas e encerra o
///   processo) e `menu` (inicia o menu quando inativo).
/// - Quando a [ConsoleView] está ativa, encaminha a linha para `handleLine` e
///   considera a entrada consumida quando apropriado.
///
/// Interações:
/// - Recebe a [ConsoleView] e a assinatura do sensor para coordenar
///   encerramento.
/// - Retorna a assinatura do stdin para controle externo.
/// ===============================================================
class InputController {
  const InputController();

  // === Inicia o listener de stdin ===
  // O que: assina stdin e retorna a assinatura para controle externo.
  // Como: decodifica linhas, interpreta comandos globais e delega à
  //       ConsoleView quando ativa.
  StreamSubscription<String> iniciar({
    required ConsoleView consoleView,
    required StreamSubscription sensorSubscription,
  }) {
    late StreamSubscription<String> stdinSubscription;
    stdinSubscription = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((input) async {
      final cmd = input.trim().toLowerCase();

      // Comando global para encerrar sempre disponível
      if (cmd == 'sair') {
        print('Encerrando o console...');
        await sensorSubscription.cancel();
        await stdinSubscription.cancel();
        Future.microtask(() => exit(0)); // finaliza o programa
        return;
      }

      // Ativa o menu (VIEW) sem bloquear o polling
      if (cmd == 'menu' && !consoleView.isActive) {
        consoleView.start();
        return;
      }

      // Roteia a entrada para o VIEW quando ativo
      if (consoleView.isActive) {
        final consumed = consoleView.handleLine(input);
        if (consumed) return;
      }
    });

    return stdinSubscription;
  }
}
