/// ===============================================================
/// HistoricoUso - Modelo da tabela `historicouso`
///
/// Representa um registro de historico de uso, associando um usuario
/// a uma descricao de acao e, opcionalmente, a data/hora em que ocorreu.
/// ===============================================================
class HistoricoUso {
  final int? id;
  final int idUsuario;
  final String acao;
  final DateTime? dataHora;

  HistoricoUso({
    this.id,
    required this.idUsuario,
    required this.acao,
    this.dataHora,
  });
}
