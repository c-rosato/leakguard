import 'package:dotenv/dotenv.dart';
import 'package:mysql1/mysql1.dart';

/// ===============================================================
/// DbService - Conexao simples com MySQL
///
/// O que faz:
/// - Le configuracoes do arquivo `.env` e abre conexoes MySQL sob demanda.
///
/// Como faz:
/// - Usa `mysql1` com `ConnectionSettings` e `MySqlConnection.connect`.
///
/// Por que assim:
/// - Evita pool e complexidade; cada DAO abre/fecha a sua conexao.
///
/// Quem usa:
/// - Todos os DAOs chamam [openConnection] antes de executar SQL.
/// ===============================================================
class DbService {
  final DotEnv dotenv;

  // === 1. Construtor ===
  DbService(this.dotenv);

  // === 2. Abre conexao MySQL a partir do .env ===
  // O que: cria e devolve uma conexao ativa do `mysql1`.
  // Como: le variaveis do .env e monta `ConnectionSettings`.
  // Por que: padronizar acesso a banco sem duplicar configuracao nos DAOs.
  Future<MySqlConnection> openConnection() async {
    final host = dotenv['DB_HOST'] ?? 'localhost';
    final port = int.tryParse(dotenv['DB_PORT'] ?? '3306') ?? 3306;
    final user = dotenv['DB_USER'] ?? 'root';
    final password = dotenv['DB_PASSWORD'] ?? '';
    final dbName = dotenv['DB_NAME'] ?? 'leakguard';

    final settings = ConnectionSettings(
      host: host,
      port: port,
      user: user,
      password: password,
      db: dbName,
    );

    return await MySqlConnection.connect(settings);
  }
}

