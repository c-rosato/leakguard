import 'package:dotenv/dotenv.dart';
import 'package:mysql1/mysql1.dart';

/// ===============================================================
/// DbService - Conexao simples com MySQL
///
/// Funcao principal:
/// - Ler configuracoes do arquivo .env
/// - Abrir uma conexao MySQL on-demand (por chamada)
///
/// Observacao:
/// Mantemos tudo simples: sem pool e sem camadas extras.
/// ===============================================================
class DbService {
  final DotEnv dotenv;

  // === 1. Construtor ===
  DbService(this.dotenv);

  // === 2. Abre conexao MySQL a partir do .env ===
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

