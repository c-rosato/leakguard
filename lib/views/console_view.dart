import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:leakguard_mq2/services/dispositivo_service.dart';
import 'package:leakguard_mq2/services/localizacao_service.dart';
import 'package:leakguard_mq2/services/leitura_service.dart';
import 'package:leakguard_mq2/services/alerta_service.dart';
import 'package:leakguard_mq2/services/historico_uso_service.dart';
import 'package:leakguard_mq2/daos/menu_read_dao.dart';
import 'package:leakguard_mq2/models/localizacao.dart';
import 'package:leakguard_mq2/models/leitura_gas.dart';
import 'package:leakguard_mq2/models/alerta.dart';
import 'package:leakguard_mq2/models/historico_uso.dart';

/// ===============================================================
/// ConsoleView - Menu de console (não bloqueante)
///
/// - Acionado via comando "menu" no stdin.
/// - Não interrompe o polling do sensor.
/// - Implementa login simples via .env e menus
///   para usuário comum e administrador.
/// ===============================================================
class ConsoleView {
  final DotEnv dotenv;
  final DispositivoService dispositivoService;
  final LocalizacaoService localizacaoService;
  final LeituraService leituraService;
  final AlertaService alertaService;
  final HistoricoUsoService historicoUsoService;
  final MenuReadDao menuReadDao;

  ConsoleView({
    required this.dotenv,
    required this.dispositivoService,
    required this.localizacaoService,
    required this.leituraService,
    required this.alertaService,
    required this.historicoUsoService,
     required this.menuReadDao,
  });

  bool _active = false;
  _MenuState _state = _MenuState.idle;

  // Campos de estado e sessão do menu
  String? _emailInput;
  String? _senhaInput;
  int? _usuarioId;
  _Perfil? _perfil;

  // Campos auxiliares para fluxos multi-etapa de admin
  String? _novoNomeLocalizacao;
  String? _novoNomeDispositivo;

  bool get isActive => _active;

  /// Inicia o fluxo do menu (entra em modo ativo e solicita o e-mail)
  void start() {
    // Inicia a sessao interativa do menu,
    // limpando estado anterior e posicionando
    // a maquina na etapa de solicitacao de e-mail.
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
    stdout.writeln('Login simples:');
    stdout.writeln('- E-mail:');
  }

  /// Encerra o menu e volta ao modo inativo
  void end() {
    // Encerra a sessao do menu e restaura
    // o estado para `idle`, removendo dados
    // de login e informacoes temporarias.
    _active = false;
    _state = _MenuState.idle;
    _emailInput = null;
    _senhaInput = null;
    _usuarioId = null;
    _perfil = null;
    _novoNomeLocalizacao = null;
    _novoNomeDispositivo = null;
    stdout.writeln('Saindo do menu.');
  }

  /// Consome uma linha de entrada quando o menu está ativo.
  /// Retorna true se a linha foi tratada aqui; false caso contrário.
  bool handleLine(String line) {
    // Roteia a linha digitada para o estado corrente da maquina de estados.
    if (!_active) return false;

    final input = line.trim();
    if (input.toLowerCase() == 'voltar') {
      end();
      return true;
    }

    switch (_state) {
      case _MenuState.idle:
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

      case _MenuState.menuComumAposListagem:
        _state = _MenuState.menuComum;
        _mostrarMenuComum();
        return true;

      case _MenuState.menuAdminAposListagem:
        _state = _MenuState.menuAdmin;
        _mostrarMenuAdmin();
        return true;

      case _MenuState.adminCriarLocalizacaoNome:
        return _tratarNomeNovaLocalizacao(input);

      case _MenuState.adminCriarLocalizacaoDescricao:
        return _tratarDescricaoNovaLocalizacao(input);

      case _MenuState.adminCriarDispositivoNome:
        return _tratarNomeNovoDispositivo(input);

      case _MenuState.adminCriarDispositivoLocalizacao:
        return _tratarLocalizacaoNovoDispositivo(input);
    }
  }

  // Exibe o menu para usuário comum
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

  // Exibe o menu para administrador
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

  // Interpreta a opcao escolhida pelo usuario comum e
  // dispara a listagem correspondente, voltando ao menu em seguida.
  bool _tratarAcaoMenuComum(String input) {
    switch (input) {
      case '1':
        _listarDispositivos();
        return true;
      case '2':
        _listarLocalizacoes();
        return true;
      case '3':
        _listarLeituras();
        return true;
      case '4':
        _listarAlertas();
        return true;
      case '5':
        _listarHistoricoUso();
        return true;
      default:
        stdout.writeln('Opção inválida.');
        _mostrarMenuComum();
        return true;
    }
  }

  // Interpreta a opcao escolhida pelo administrador e
  // executa listagens ou inicia fluxos de criacao.
  bool _tratarAcaoMenuAdmin(String input) {
    switch (input) {
      case '1':
        _listarDispositivos();
        return true;
      case '2':
        _listarLocalizacoes();
        return true;
      case '3':
        _listarLeituras();
        return true;
      case '4':
        _listarAlertas();
        return true;
      case '5':
        _listarHistoricoUso();
        return true;
      case '6':
        _state = _MenuState.adminCriarLocalizacaoNome;
        stdout.writeln('\n[Admin] Criar nova localização');
        stdout.writeln('Informe o nome da nova localização:');
        return true;
      case '7':
        _state = _MenuState.adminCriarDispositivoNome;
        stdout.writeln('\n[Admin] Criar novo dispositivo');
        stdout.writeln('Informe o nome do novo dispositivo:');
        return true;
      default:
        stdout.writeln('Opção inválida.');
        _mostrarMenuAdmin();
        return true;
    }
  }

  // Listagens
  // Lista dispositivos com seu estado `ativo` e a localizacao associada.
  void _listarDispositivos() async {
    try {
      final lista = await menuReadDao.listarDispositivos();
      stdout.writeln('\n=== Dispositivos cadastrados ===');
      if (lista.isEmpty) {
        stdout.writeln('Nenhum dispositivo encontrado.');
      } else {
        for (final row in lista) {
          final id = row['id'] as int?;
          final nome = row['nome'] as String;
          final ativo = row['ativo'] as bool;
          final idLoc = row['id_localizacao'] as int?;
          stdout.writeln(
            'ID: $id | Nome: $nome | Ativo: ${ativo ? "Sim" : "Não"} | Localização: ${idLoc ?? "-"}',
          );
        }
      }
    } catch (e) {
      stdout.writeln('Erro ao listar dispositivos: $e');
    }

    if (_perfil == _Perfil.admin) {
      _state = _MenuState.menuAdminAposListagem;
    } else {
      _state = _MenuState.menuComumAposListagem;
    }

    stdout.writeln(
      '\n(Pressione ENTER para voltar ao menu ou digite "voltar" para sair.)',
    );
  }

  // Lista localizacoes cadastradas com seus textos descritivos.
  void _listarLocalizacoes() async {
    try {
      final List<Localizacao> lista =
          await menuReadDao.listarLocalizacoes();
      stdout.writeln('\n=== Localizações cadastradas ===');
      if (lista.isEmpty) {
        stdout.writeln('Nenhuma localização encontrada.');
      } else {
        for (final loc in lista) {
          stdout.writeln(
            'ID: ${loc.id} | Nome: ${loc.nomeLocal} | Descrição: ${loc.descricao ?? "-"}',
          );
        }
      }
    } catch (e) {
      stdout.writeln('Erro ao listar localizações: $e');
    }

    if (_perfil == _Perfil.admin) {
      _state = _MenuState.menuAdminAposListagem;
    } else {
      _state = _MenuState.menuComumAposListagem;
    }

    stdout.writeln(
      '\n(Pressione ENTER para voltar ao menu ou digite "voltar" para sair.)',
    );
  }

  // Lista leituras de gas gravadas, exibindo dispositivo, localizacao,
  // data/hora e nivel da leitura.
  void _listarLeituras() async {
    try {
      final List<LeituraGas> lista = await menuReadDao.listarLeituras();
      stdout.writeln('\n=== Leituras de gás ===');
      if (lista.isEmpty) {
        stdout.writeln('Nenhuma leitura encontrada.');
      } else {
        for (final l in lista) {
          stdout.writeln(
            'ID: ${l.id} | Disp: ${l.idDispositivo} | Loc: ${l.idLocalizacao ?? "-"} | '
            'Data: ${l.dataHora} | Detectado: ${l.foiDetectado ? "Sim" : "Não"} | '
            'Nível: ${l.nivelGas.toStringAsFixed(2)} ppm',
          );
        }
      }
    } catch (e) {
      stdout.writeln('Erro ao listar leituras: $e');
    }

    if (_perfil == _Perfil.admin) {
      _state = _MenuState.menuAdminAposListagem;
    } else {
      _state = _MenuState.menuComumAposListagem;
    }

    stdout.writeln(
      '\n(Pressione ENTER para voltar ao menu ou digite "voltar" para sair.)',
    );
  }

  // Lista alertas gravados a partir das leituras avaliadas como moderadas
  // ou criticas.
  void _listarAlertas() async {
    try {
      final List<Alerta> lista = await menuReadDao.listarAlertas();
      stdout.writeln('\n=== Alertas gerados ===');
      if (lista.isEmpty) {
        stdout.writeln('Nenhum alerta encontrado.');
      } else {
        for (final a in lista) {
          stdout.writeln(
            'ID: ${a.id} | Leitura: ${a.idLeitura} | Nível: ${a.nivelGas.toStringAsFixed(2)} ppm | '
            'Data: ${a.dataHora ?? "-"} | Msg: ${a.mensagem}',
          );
        }
      }
    } catch (e) {
      stdout.writeln('Erro ao listar alertas: $e');
    }

    if (_perfil == _Perfil.admin) {
      _state = _MenuState.menuAdminAposListagem;
    } else {
      _state = _MenuState.menuComumAposListagem;
    }

    stdout.writeln(
      '\n(Pressione ENTER para voltar ao menu ou digite "voltar" para sair.)',
    );
  }

  // Versao com pausa apos a listagem de historico,
  // para nao sobrescrever o resultado imediatamente com o menu.
  void _listarHistoricoUso() async {
    try {
      final List<HistoricoUso> lista =
          await menuReadDao.listarHistoricoUso();
      stdout.writeln('\n=== Historico de uso ===');
      if (lista.isEmpty) {
        stdout.writeln('Nenhum registro de historico encontrado.');
      } else {
        for (final h in lista) {
          stdout.writeln(
            'ID: ${h.id} | Usuǭrio: ${h.idUsuario} | Data: ${h.dataHora ?? "-"} | Acao: ${h.acao}',
          );
        }
      }
    } catch (e) {
      stdout.writeln('Erro ao listar historico de uso: $e');
    }

    if (_perfil == _Perfil.admin) {
      _state = _MenuState.menuAdminAposListagem;
    } else {
      _state = _MenuState.menuComumAposListagem;
    }

    stdout.writeln(
      '\n(Pressione ENTER para voltar ao menu ou digite "voltar" para sair.)',
    );
  }
}

enum _MenuState {
  idle,
  loginEmail,
  loginSenha,
  menuComum,
  menuAdmin,
  menuComumAposListagem,
  menuAdminAposListagem,
  adminCriarLocalizacaoNome,
  adminCriarLocalizacaoDescricao,
  adminCriarDispositivoNome,
  adminCriarDispositivoLocalizacao,
}

enum _Perfil {
  comum,
  admin,
}

// Extensao com a logica de validacao de login,
// baseada nas credenciais definidas no arquivo `.env`.
extension _Login on ConsoleView {
  // Verifica se o par email/senha corresponde a um dos perfis
  // configurados no `.env` (admin ou usuario comum) e,
  // em caso positivo, ajusta `_perfil` e `_usuarioId`.
  bool _validarLogin(String email, String senha) {
    final adminEmail = dotenv['LOGIN_ADMIN_EMAIL'];
    final adminSenha = dotenv['LOGIN_ADMIN_SENHA'];
    final adminIdStr = dotenv['LOGIN_ADMIN_ID'];

    final userEmail = dotenv['LOGIN_USER_EMAIL'];
    final userSenha = dotenv['LOGIN_USER_SENHA'];
    final userIdStr = dotenv['LOGIN_USER_ID'];

    if (adminEmail != null &&
        adminSenha != null &&
        email == adminEmail &&
        senha == adminSenha) {
      _perfil = _Perfil.admin;
      _usuarioId = int.tryParse(adminIdStr ?? '');
      return true;
    }

    if (userEmail != null &&
        userSenha != null &&
        email == userEmail &&
        senha == userSenha) {
      _perfil = _Perfil.comum;
      _usuarioId = int.tryParse(userIdStr ?? '');
      return true;
    }

    return false;
  }
}

// Extensao que encapsula os fluxos multi-etapa das acoes administrativas,
// como criacao de localizacao e de dispositivo.
extension _AdminAcoes on ConsoleView {
  // Primeira etapa do fluxo de criacao de localizacao:
  // captura e valida o nome informado.
  bool _tratarNomeNovaLocalizacao(String input) {
    _novoNomeLocalizacao = input.trim();
    if (_novoNomeLocalizacao == null || _novoNomeLocalizacao!.isEmpty) {
      stdout.writeln(
        'Nome não pode ser vazio. Informe o nome da nova localização:',
      );
      return true;
    }

    _state = _MenuState.adminCriarLocalizacaoDescricao;
    stdout.writeln('Informe uma descrição (ou deixe em branco):');
    return true;
  }

  // Segunda etapa do fluxo de criacao de localizacao:
  // recebe a descricao opcional e efetiva o INSERT via service/DAO,
  // registrando tambem a acao no historico.
  bool _tratarDescricaoNovaLocalizacao(String input) {
    final descricao = input.trim().isEmpty ? null : input.trim();

    final nome = _novoNomeLocalizacao;
    if (nome == null || nome.isEmpty) {
      stdout.writeln('Nome da localização perdido. Voltando ao menu.');
      _state = _MenuState.menuAdmin;
      _mostrarMenuAdmin();
      return true;
    }

    () async {
      try {
        final id = await localizacaoService.criarLocalizacao(
          Localizacao(nomeLocal: nome, descricao: descricao),
        );
        stdout.writeln('Localização criada com sucesso. ID: $id');
        if (_usuarioId != null && _perfil == _Perfil.admin) {
          await historicoUsoService.registrarAcao(
            idUsuario: _usuarioId!,
            acao: 'Criou localização ID=$id, nome="$nome"',
          );
        }
      } catch (e) {
        stdout.writeln('Erro ao criar localização: $e');
      }
      _state = _MenuState.menuAdmin;
      _mostrarMenuAdmin();
    }();

    return true;
  }

  // Primeira etapa do fluxo de criacao de dispositivo:
  // captura e valida o nome do novo dispositivo.
  bool _tratarNomeNovoDispositivo(String input) {
    _novoNomeDispositivo = input.trim();
    if (_novoNomeDispositivo == null || _novoNomeDispositivo!.isEmpty) {
      stdout.writeln(
        'Nome não pode ser vazio. Informe o nome do novo dispositivo:',
      );
      return true;
    }

    _state = _MenuState.adminCriarDispositivoLocalizacao;
    stdout.writeln('Informe o ID da localização do dispositivo:');
    return true;
  }

  // Segunda etapa do fluxo de criacao de dispositivo:
  // recebe o ID de localizacao, cria o dispositivo e registra
  // a acao no historico de uso.
  bool _tratarLocalizacaoNovoDispositivo(String input) {
    final idLoc = int.tryParse(input.trim());
    if (idLoc == null) {
      stdout.writeln(
        'ID de localização inválido. Informe um número inteiro:',
      );
      return true;
    }

    final nome = _novoNomeDispositivo;
    if (nome == null || nome.isEmpty) {
      stdout.writeln('Nome do dispositivo perdido. Voltando ao menu.');
      _state = _MenuState.menuAdmin;
      _mostrarMenuAdmin();
      return true;
    }

    () async {
      try {
        final idDispositivo = await dispositivoService.criarNovoDispositivo(
          nome: nome,
          idLocalizacao: idLoc,
        );
        stdout.writeln(
          'Dispositivo criado com sucesso. ID: $idDispositivo',
        );
        if (_usuarioId != null && _perfil == _Perfil.admin) {
          await historicoUsoService.registrarAcao(
            idUsuario: _usuarioId!,
            acao:
                'Criou dispositivo ID=$idDispositivo, nome="$nome", id_localizacao=$idLoc',
          );
        }
      } catch (e) {
        stdout.writeln('Erro ao criar dispositivo: $e');
      }
      _state = _MenuState.menuAdmin;
      _mostrarMenuAdmin();
    }();

    return true;
  }
}
