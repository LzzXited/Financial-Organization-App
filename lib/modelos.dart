import 'dart:math';

final _rnd = Random();

/// Gera um id único que também ordena pela hora de criação.
String novoId() =>
    '${DateTime.now().microsecondsSinceEpoch}${_rnd.nextInt(9000) + 1000}';

/// Remove as horas de uma data (fica só dia/mês/ano).
DateTime soDia(DateTime d) => DateTime(d.year, d.month, d.day);

enum TipoTransacao { entrada, saida, rendimento }

enum StatusTransacao { recebido, aReceber, pago, aPagar }

/// Entrada, saída ou rendimento. Valores sempre em centavos.
class Transacao {
  final String id;
  TipoTransacao tipo;
  int valor;
  String descricao;
  DateTime data;
  StatusTransacao status;

  Transacao({
    required this.id,
    required this.tipo,
    required this.valor,
    required this.descricao,
    required this.data,
    required this.status,
  });

  bool get pendente =>
      status == StatusTransacao.aReceber || status == StatusTransacao.aPagar;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo.name,
        'valor': valor,
        'descricao': descricao,
        'data': data.toIso8601String(),
        'status': status.name,
      };

  factory Transacao.fromJson(Map<String, dynamic> j) => Transacao(
        id: j['id'] as String,
        tipo: TipoTransacao.values.byName(j['tipo'] as String),
        valor: (j['valor'] as num).toInt(),
        descricao: (j['descricao'] ?? '') as String,
        data: DateTime.parse(j['data'] as String),
        status: StatusTransacao.values.byName(j['status'] as String),
      );
}

/// Movimento de uma dívida (empréstimo / pagamento) ou de um cofre
/// (depósito / retirada).
/// [positivo] = empréstimo (na dívida) ou depósito (no cofre).
class Movimento {
  final String id;
  bool positivo;
  int valor;
  DateTime data;
  String descricao;

  /// Só para empréstimos: se o valor saiu do meu dinheiro livre.
  /// Desligado serve para registrar empréstimos antigos.
  bool afetaLivre;

  Movimento({
    required this.id,
    required this.positivo,
    required this.valor,
    required this.data,
    this.descricao = '',
    this.afetaLivre = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'positivo': positivo,
        'valor': valor,
        'data': data.toIso8601String(),
        'descricao': descricao,
        'afetaLivre': afetaLivre,
      };

  factory Movimento.fromJson(Map<String, dynamic> j) => Movimento(
        id: j['id'] as String,
        positivo: j['positivo'] as bool,
        valor: (j['valor'] as num).toInt(),
        data: DateTime.parse(j['data'] as String),
        descricao: (j['descricao'] ?? '') as String,
        afetaLivre: (j['afetaLivre'] ?? true) as bool,
      );
}

/// Usado tanto para uma pessoa que me deve (devedor) quanto para um cofre.
class Registro {
  final String id;
  String nome;
  List<Movimento> movs;

  Registro({required this.id, required this.nome, List<Movimento>? movs})
      : movs = movs ?? [];

  int get totalPositivo =>
      movs.where((m) => m.positivo).fold(0, (a, m) => a + m.valor);
  int get totalNegativo =>
      movs.where((m) => !m.positivo).fold(0, (a, m) => a + m.valor);

  /// Dívida: quanto falta a pessoa pagar. Cofre: quanto está guardado.
  int get saldo => totalPositivo - totalNegativo;

  DateTime? get ultimaData {
    if (movs.isEmpty) return null;
    return movs.map((m) => m.data).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'movs': movs.map((m) => m.toJson()).toList(),
      };

  factory Registro.fromJson(Map<String, dynamic> j) => Registro(
        id: j['id'] as String,
        nome: (j['nome'] ?? '') as String,
        movs: ((j['movs'] ?? []) as List)
            .map((e) => Movimento.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Conta que se repete todo mês, com lembrete no dia do vencimento.
class Assinatura {
  final String id;
  String descricao;
  int valor;
  int dia;
  bool lembrete;
  final int notifId;

  /// Mês ('aaaa-mm') a partir do qual a assinatura passa a ser cobrada.
  String inicio;

  /// 'aaaa-mm' -> id da saída que foi lançada ao pagar aquele mês.
  Map<String, String> pagamentos;

  Assinatura({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.dia,
    this.lembrete = true,
    int? notifId,
    String? inicio,
    Map<String, String>? pagamentos,
  })  : notifId = notifId ?? _rnd.nextInt(1 << 30),
        inicio = inicio ?? chaveMes(DateTime.now()),
        pagamentos = pagamentos ?? {};

  static String chaveMes(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static DateTime mesDaChave(String k) =>
      DateTime(int.parse(k.substring(0, 4)), int.parse(k.substring(5, 7)));

  bool pagoNoMes(DateTime d) => pagamentos.containsKey(chaveMes(d));

  /// Meses (do mais antigo ao atual) que ainda não foram pagos.
  /// Cada mês novo que começa entra aqui sozinho, até ser pago.
  List<String> mesesEmAberto([DateTime? referencia]) {
    final hoje = referencia ?? DateTime.now();
    final fim = DateTime(hoje.year, hoje.month);
    var d = mesDaChave(inicio);
    final r = <String>[];
    var guarda = 0;
    while (!d.isAfter(fim) && guarda < 600) {
      final k = chaveMes(d);
      if (!pagamentos.containsKey(k)) r.add(k);
      d = DateTime(d.year, d.month + 1);
      guarda++;
    }
    return r;
  }

  /// Quanto ainda falta pagar (valor × meses em aberto).
  int get valorEmAberto => valor * mesesEmAberto().length;

  bool get emDia => mesesEmAberto().isEmpty;

  /// Data de vencimento dentro de um mês ('aaaa-mm').
  DateTime vencimentoNoMes(String chave) {
    final m = mesDaChave(chave);
    final ultimo = DateTime(m.year, m.month + 1, 0).day;
    return DateTime(m.year, m.month, dia > ultimo ? ultimo : dia);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'descricao': descricao,
        'valor': valor,
        'dia': dia,
        'lembrete': lembrete,
        'notifId': notifId,
        'inicio': inicio,
        'pagamentos': pagamentos,
      };

  factory Assinatura.fromJson(Map<String, dynamic> j) {
    final pags = Map<String, String>.from((j['pagamentos'] ?? {}) as Map);
    var inicio = j['inicio'] as String?;
    if (inicio == null) {
      // Dados antigos: começa no primeiro mês pago ou no mês atual.
      final chaves = pags.keys.toList()..sort();
      inicio = chaves.isNotEmpty ? chaves.first : chaveMes(DateTime.now());
    }
    return Assinatura(
        id: j['id'] as String,
        descricao: (j['descricao'] ?? '') as String,
        valor: (j['valor'] as num).toInt(),
        dia: (j['dia'] as num).toInt(),
        lembrete: (j['lembrete'] ?? true) as bool,
        notifId: (j['notifId'] as num?)?.toInt(),
        inicio: inicio,
        pagamentos: pags,
      );
  }
}
