import 'package:dotenv/dotenv.dart';
import 'package:mysql1/mysql1.dart';

/// ===============================================================
/// DbService - Conexao simples com MySQL
///
/// Responsabilidades:
/// - Ler configuracoes de conexao a partir do arquivo `.env`.
/// - Fornecer instancias de [MySqlConnection] sob demanda para os DAOs.
///
/// Implementacao:
/// - Usa `mysql1` com [ConnectionSettings] preenchido a partir das
///   variaveis de ambiente.
/// - Nao mantem pool de conexoes; cada chamada a [openConnection]
///   abre uma nova conexao.
///
/// Uso:
/// - Todos os DAOs invocam [openConnection] antes de executar comandos SQL.
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
