import 'dart:io';
import 'package:dotenv/dotenv.dart';

/// ===============================================================
/// ConsoleView - Estrutura básica do menu (não bloqueante)
///
/// O que faz:
/// - Gerencia um menu interativo acionado pelo comando "menu",
///   sem interromper a stream/polling do fluxo principal.
/// - Operar como uma pequena máquina de estados, consumindo as
///
/// - Ainda sem lógica real de login/consultas — apenas estrutura.
///
/// Como faz:
/// - `start()` ativa o menu e solicita o e-mail.
/// - Enquanto ativo, todas as linhas (exceto 'sair') são encaminhadas para
///   view.handleLine(...). O método devolve true quando consome a linha.
/// - Para sair do menu e voltar ao modo idle, digite 'voltar'.
/// ===============================================================
class ConsoleView {
  final DotEnv dotenv;

  ConsoleView(this.dotenv);

  bool _active = false;
  _MenuState _state = _MenuState.idle;

  // Campos de estado e sessão do menu
  String? _emailInput;
  String? _senhaInput;
  int? _usuarioId;
  _Perfil? _perfil;

  bool get isActive => _active;

  /// Inicia o fluxo do menu (entra em modo ativo e solicita o e-mail)
  void start() {
    if (_active) {
      stdout.writeln('Menu já está ativo.');
      return;
    }
    _active = true;
    _state = _MenuState.loginEmail;
    _emailInput = null;
    _senhaInput = null;
    _usuarioId = null;
    _perfil = null;

    stdout.writeln('=== LeakGuard - Menu Console ===');
    stdout.writeln('(Digite "voltar" a qualquer momento para sair do menu)');
    stdout.writeln('Login simples (estrutura):');
    stdout.writeln('- E-mail:');
  }

  /// Encerra o menu e volta ao modo inativo
  void end() {
    _active = false;
    _state = _MenuState.idle;
    _emailInput = null;
    _senhaInput = null;
    _usuarioId = null;
    _perfil = null;
    stdout.writeln('Saindo do menu.');
  }

  /// Consome uma linha de entrada quando o menu está ativo.
  /// Retorna true se a linha foi tratada aqui; false caso contrário.
  bool handleLine(String line) {
    if (!_active) return false;

    final input = line.trim();
    if (input.toLowerCase() == 'voltar') {
      end();
      return true;
    }

    switch (_state) {
      case _MenuState.idle:
        // Não deveria ocorrer quando _active = true, mas evitamos queda.
        _state = _MenuState.loginEmail;
        stdout.writeln('- E-mail:');
        return true;

      case _MenuState.loginEmail:
        _emailInput = input;
        _state = _MenuState.loginSenha;
        stdout.writeln('- Senha:');
        return true;

      case _MenuState.loginSenha:
        _senhaInput = input;
        final ok = _validarLogin(_emailInput ?? '', _senhaInput ?? '');
        if (!ok) {
          stdout.writeln('Credenciais inválidas. Tente novamente.');
          _state = _MenuState.loginEmail;
          stdout.writeln('- E-mail:');
          return true;
        }

        if (_perfil == _Perfil.admin) {
          _state = _MenuState.menuAdmin;
          stdout.writeln('\n[Login OK] Perfil: ADMIN | id=$_usuarioId');
          _mostrarMenuAdmin();
        } else {
          _state = _MenuState.menuComum;
          stdout.writeln('\n[Login OK] Perfil: COMUM | id=$_usuarioId');
          _mostrarMenuComum();
        }
        return true;

      case _MenuState.menuComum:
        return _tratarAcaoMenuComum(input);

      case _MenuState.menuAdmin:
        return _tratarAcaoMenuAdmin(input);
    }
  }

  // Exibe o menu para usuário comum (estrutura)
  void _mostrarMenuComum() {
    stdout.writeln('\n=== Menu (Usuário Comum) ===');
    stdout.writeln('1) Listar dispositivos');
    stdout.writeln('2) Listar localizações');
    stdout.writeln('3) Listar leituras');
    stdout.writeln('4) Listar alertas');
    stdout.writeln('5) Listar histórico de uso');
    stdout.writeln('voltar) Sair do menu');
    stdout.writeln('Selecione uma opção:');
  }

  // Exibe o menu para administrador (estrutura)
  void _mostrarMenuAdmin() {
    stdout.writeln('\n=== Menu (Administrador) ===');
    stdout.writeln('1) Listar dispositivos');
    stdout.writeln('2) Listar localizações');
    stdout.writeln('3) Listar leituras');
    stdout.writeln('4) Listar alertas');
    stdout.writeln('5) Listar histórico de uso');
    stdout.writeln('6) Criar nova localização');
    stdout.writeln('7) Criar novo dispositivo');
    stdout.writeln('voltar) Sair do menu');
    stdout.writeln('Selecione uma opção:');
  }

  bool _tratarAcaoMenuComum(String input) {
    switch (input) {
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
        stdout.writeln('[Estrutura] Ação $input selecionada (implementação na próxima etapa).');
        _mostrarMenuComum();
        return true;
      default:
        stdout.writeln('Opção inválida.');
        _mostrarMenuComum();
        return true;
    }
  }

  bool _tratarAcaoMenuAdmin(String input) {
    switch (input) {
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
        stdout.writeln('[Estrutura] Ação $input selecionada (implementação na próxima etapa).');
        _mostrarMenuAdmin();
        return true;
      default:
        stdout.writeln('Opção inválida.');
        _mostrarMenuAdmin();
        return true;
    }
  }
}

enum _MenuState {
  idle,
  loginEmail,
  loginSenha,
  menuComum,
  menuAdmin,
}

enum _Perfil {
  comum,
  admin,
}

extension _Login on ConsoleView {
  bool _validarLogin(String email, String senha) {
    final adminEmail = dotenv['LOGIN_ADMIN_EMAIL'];
    final adminSenha = dotenv['LOGIN_ADMIN_SENHA'];
    final adminIdStr = dotenv['LOGIN_ADMIN_ID'];

    final userEmail = dotenv['LOGIN_USER_EMAIL'];
    final userSenha = dotenv['LOGIN_USER_SENHA'];
    final userIdStr = dotenv['LOGIN_USER_ID'];

    // Verificações simples; se variáveis não existirem, falha o login
    if (adminEmail != null && adminSenha != null &&
        email == adminEmail && senha == adminSenha) {
      _perfil = _Perfil.admin;
      _usuarioId = int.tryParse(adminIdStr ?? '');
      return true;
    }

    if (userEmail != null && userSenha != null &&
        email == userEmail && senha == userSenha) {
      _perfil = _Perfil.comum;
      _usuarioId = int.tryParse(userIdStr ?? '');
      return true;
    }

    return false;
  }
}
