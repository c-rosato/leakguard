/// ===============================================================
/// Usuario - Modelo da tabela `usuario`
///
/// Representa um usuario do sistema com seus dados principais,
/// incluindo o tipo (`comum` ou `administrador`) definido no banco.
/// ===============================================================
class Usuario {
  final int? id;
  final String nome;
  final String email;
  final String senha;
  final String tipo;

  Usuario({
    this.id,
    required this.nome,
    required this.email,
    required this.senha,
    required this.tipo,
  });
}

