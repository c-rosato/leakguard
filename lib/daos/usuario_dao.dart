import 'package:mysql1/mysql1.dart';
import 'package:leakguard_mq2/services/db_service.dart';
import 'package:leakguard_mq2/models/usuario.dart';

/// ===============================================================
/// UsuarioDao - Operacoes simples em `usuario`
///
/// Responsabilidades:
/// - Criar ou atualizar registros na tabela `usuario` com IDs definidos
///   externamente (por exemplo, configurados via `.env`).
///
/// Implementacao:
/// - Abre conexoes sob demanda via [DbService.openConnection].
/// - Executa `INSERT ... ON DUPLICATE KEY UPDATE` para manter consistentes
///   os dados de nome, email, senha e tipo para um mesmo ID.
///
/// Uso:
/// - Utilizado por [UsuarioService] para semear usuarios basicos
///   que serao referenciados em `historicouso`.
/// ===============================================================
class UsuarioDao {
  final DbService dbService;

  UsuarioDao(this.dbService);

  /// Cria ou atualiza um usuario com ID fixo.
  /// O que: garante que exista um registro na tabela `usuario` com o ID informado.
  /// Como: executa `INSERT ... ON DUPLICATE KEY UPDATE` para manter nome, email,
  ///       senha e tipo sincronizados com os valores fornecidos.
  /// Por que: assegurar que IDs configurados no `.env` possam ser referenciados
  ///          em `historicouso` sem violar integridade referencial.
  Future<void> seedUsuarioFixo(Usuario usuario) async {
    final MySqlConnection conn = await dbService.openConnection();

    try {
      final nome = usuario.nome.replaceAll("'", "''");
      final email = usuario.email.replaceAll("'", "''");
      final senha = usuario.senha.replaceAll("'", "''");
      final tipo = usuario.tipo.replaceAll("'", "''");

      await conn.query(
        "INSERT INTO usuario (id, nome, email, senha, tipo) "
        "VALUES (${usuario.id}, '$nome', '$email', '$senha', '$tipo') "
        "ON DUPLICATE KEY UPDATE "
        "nome = VALUES(nome), "
        "email = VALUES(email), "
        "senha = VALUES(senha), "
        "tipo = VALUES(tipo)",
      );
    } finally {
      await conn.close();
    }
  }
}
