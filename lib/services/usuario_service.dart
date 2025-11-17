import 'package:dotenv/dotenv.dart';
import 'package:leakguard_mq2/daos/usuario_dao.dart';
import 'package:leakguard_mq2/models/usuario.dart';

/// ===============================================================
/// UsuarioService - Regras simples para `usuario`
///
/// Responsabilidades:
/// - Garantir que existam usuarios basicos cadastrados na tabela `usuario`
///   com IDs definidos no arquivo `.env`.
///
/// Implementacao:
/// - Le do `.env` os dados de admin e usuario comum.
/// - Cria instancias de [Usuario] e delega a persistencia ao [UsuarioDao],
///   utilizando IDs fixos que serao referenciados em `historicouso`.
/// ===============================================================
class UsuarioService {
  final UsuarioDao usuarioDao;

  UsuarioService({required this.usuarioDao});

  /// Cria/atualiza registros basicos de admin/usuario a partir do .env.
  ///
  /// O login continua baseado apenas no .env; aqui garantimos que os IDs
  /// usados em `historicouso.id_usuario` existam na tabela.
  Future<void> seedUsuariosPadrao(DotEnv dotenv) async {
    final adminId = int.tryParse(dotenv['LOGIN_ADMIN_ID'] ?? '');
    final adminEmail = dotenv['LOGIN_ADMIN_EMAIL'];
    final adminSenha = dotenv['LOGIN_ADMIN_SENHA'];

    if (adminId != null && adminEmail != null && adminSenha != null) {
      final admin = Usuario(
        id: adminId,
        nome: 'Administrador LeakGuard',
        email: adminEmail,
        senha: adminSenha,
        tipo: 'administrador',
      );
      await usuarioDao.seedUsuarioFixo(admin);
    }

    final userId = int.tryParse(dotenv['LOGIN_USER_ID'] ?? '');
    final userEmail = dotenv['LOGIN_USER_EMAIL'];
    final userSenha = dotenv['LOGIN_USER_SENHA'];

    if (userId != null && userEmail != null && userSenha != null) {
      final user = Usuario(
        id: userId,
        nome: 'Usuario LeakGuard',
        email: userEmail,
        senha: userSenha,
        tipo: 'comum',
      );
      await usuarioDao.seedUsuarioFixo(user);
    }
  }
}
