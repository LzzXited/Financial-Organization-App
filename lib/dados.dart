import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'modelos.dart';
import 'notificacoes.dart';

/// Guarda todos os dados do app e faz as contas.
class Dados extends ChangeNotifier {
  static const _chave = 'financas_dados_v1';
  static const _chaveOcultar = 'financas_ocultar';

  String nome = '';
  bool ocultarValores = false;
  bool carregado = false;
  List<Transacao> transacoes = [];
  List<Registro> devedores = [];
  List<Registro> cofres = [];
  List<Assinatura> assinaturas = [];

  // ------------------------------------------------------------ persistência

  Future<void> carregar() async {
    final p = await SharedPreferences.getInstance();
    ocultarValores = p.getBool(_chaveOcultar) ?? false;
    final s = p.getString(_chave);
    if (s != null) {
      try {
        _deMapa(Map<String, dynamic>.from(jsonDecode(s) as Map));
      } catch (e) {
        debugPrint('Erro ao ler dados: $e');
      }
    }
    carregado = true;
    notifyListeners();
  }

  Future<void> _salvar() async {
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_chave, jsonEncode(paraMapa()));
  }

  Map<String, dynamic> paraMapa() => {
        'app': 'financas',
        'versao': 1,
        'exportadoEm': DateTime.now().toIso8601String(),
        'nome': nome,
        'transacoes': transacoes.map((t) => t.toJson()).toList(),
        'devedores': devedores.map((d) => d.toJson()).toList(),
        'cofres': cofres.map((c) => c.toJson()).toList(),
        'assinaturas': assinaturas.map((a) => a.toJson()).toList(),
      };

  void _deMapa(Map<String, dynamic> j) {
    List<Map<String, dynamic>> lista(String k) => ((j[k] ?? []) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    nome = (j['nome'] ?? '') as String;
    transacoes = lista('transacoes').map(Transacao.fromJson).toList();
    devedores = lista('devedores').map(Registro.fromJson).toList();
    cofres = lista('cofres').map(Registro.fromJson).toList();
    assinaturas = lista('assinaturas').map(Assinatura.fromJson).toList();
  }

  /// Substitui tudo pelos dados de um backup. Lança erro se o arquivo for inválido.
  Future<void> importar(String texto) async {
    final j = Map<String, dynamic>.from(jsonDecode(texto) as Map);
    if (j['app'] != 'financas') {
      throw const FormatException('Este arquivo não é um backup deste app.');
    }
    for (final a in assinaturas) {
      await Notificacoes.cancelar(a);
    }
    _deMapa(j);
    await _salvar();
    await reagendarLembretes();
  }

  Future<void> reagendarLembretes() async {
    for (final a in assinaturas) {
      await Notificacoes.agendar(a);
    }
  }

  Future<void> setOcultar(bool v) async {
    ocultarValores = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_chaveOcultar, v);
  }

  Future<void> setNome(String n) async {
    nome = n.trim();
    await _salvar();
  }

  // ------------------------------------------------------------------ contas

  int _soma(Iterable<Transacao> it) => it.fold(0, (a, t) => a + t.valor);

  int get _entradasRecebidas => _soma(transacoes.where((t) =>
      t.tipo == TipoTransacao.entrada && t.status == StatusTransacao.recebido));

  int get _saidasPagas => _soma(transacoes.where((t) =>
      t.tipo == TipoTransacao.saida && t.status == StatusTransacao.pago));

  int get aReceber => _soma(transacoes.where((t) =>
      t.tipo == TipoTransacao.entrada && t.status == StatusTransacao.aReceber));

  int get aPagar => _soma(transacoes.where((t) =>
      t.tipo == TipoTransacao.saida && t.status == StatusTransacao.aPagar));

  /// Assinaturas deste mês (e de meses anteriores) que ainda não foram pagas.
  /// Já descontam do saldo antes de pagar, para você não gastar esse dinheiro.
  int get assinaturasEmAberto =>
      assinaturas.fold(0, (s, a) => s + a.valorEmAberto);

  /// Contas a pagar + assinaturas em aberto.
  int get aPagarTotal => aPagar + assinaturasEmAberto;

  /// Soma de todos os rendimentos.
  int get investido =>
      _soma(transacoes.where((t) => t.tipo == TipoTransacao.rendimento));

  /// Quanto as pessoas ainda me devem.
  int get naRua => devedores.fold(0, (a, d) => a + d.saldo);

  /// Dinheiro guardado para outras pessoas (não é meu).
  int get totalCofres => cofres.fold(0, (a, c) => a + c.saldo);

  /// Efeito das dívidas no dinheiro livre:
  /// emprestar tira do livre, receber pagamento volta para o livre.
  int get _efeitoDividas {
    var v = 0;
    for (final d in devedores) {
      for (final m in d.movs) {
        if (m.positivo) {
          if (m.afetaLivre) v -= m.valor;
        } else {
          v += m.valor;
        }
      }
    }
    return v;
  }

  /// Dinheiro disponível na mão / na conta (sem contar cofres de terceiros).
  int get livre => _entradasRecebidas - _saidasPagas + _efeitoDividas;

  /// Saldo geral = Livre + Investido + Na rua − A pagar − assinaturas em aberto.
  /// Emprestar ou receber de volta não muda o saldo (o dinheiro continua meu).
  /// Os cofres não entram (o dinheiro não é meu).
  int get saldoGeral => livre + investido + naRua - aPagarTotal;

  // ------------------------------------------------------------- transações

  Future<void> salvarTransacao(Transacao t) async {
    final i = transacoes.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      transacoes[i] = t;
    } else {
      transacoes.add(t);
    }
    await _salvar();
  }

  Future<void> excluirTransacao(Transacao t) async {
    transacoes.removeWhere((x) => x.id == t.id);
    for (final a in assinaturas) {
      a.pagamentos.removeWhere((_, id) => id == t.id);
    }
    await _salvar();
  }

  /// Marca uma conta "a pagar" como paga ou "a receber" como recebida.
  Future<void> concluir(Transacao t, {DateTime? data}) async {
    t.status = t.tipo == TipoTransacao.entrada
        ? StatusTransacao.recebido
        : StatusTransacao.pago;
    if (data != null) t.data = soDia(data);
    await _salvar();
  }

  // ------------------------------------------------------------- assinaturas

  Future<void> salvarAssinatura(Assinatura a) async {
    final i = assinaturas.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      assinaturas[i] = a;
    } else {
      assinaturas.add(a);
    }
    await _salvar();
    await Notificacoes.agendar(a);
  }

  Future<void> excluirAssinatura(Assinatura a) async {
    assinaturas.removeWhere((x) => x.id == a.id);
    await _salvar();
    await Notificacoes.cancelar(a);
  }

  /// Lança a assinatura como uma saída paga na data escolhida.
  /// Quita o mês em aberto mais antigo (ou o mês informado em [mes]).
  Future<void> pagarAssinatura(Assinatura a, DateTime data,
      {int? valor, String? descricao, String? mes}) async {
    final abertos = a.mesesEmAberto();
    final chave = mes ?? (abertos.isNotEmpty ? abertos.first : Assinatura.chaveMes(data));
    final t = Transacao(
      id: novoId(),
      tipo: TipoTransacao.saida,
      valor: valor ?? a.valor,
      descricao: (descricao == null || descricao.isEmpty) ? a.descricao : descricao,
      data: soDia(data),
      status: StatusTransacao.pago,
    );
    transacoes.add(t);
    a.pagamentos[chave] = t.id;
    await _salvar();
  }

  // ------------------------------------------------- dívidas (pessoas) e cofres

  Registro? devedor(String id) {
    for (final d in devedores) {
      if (d.id == id) return d;
    }
    return null;
  }

  Registro? cofre(String id) {
    for (final c in cofres) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Encontra a pessoa pelo nome (sem diferenciar maiúsculas) ou cria uma nova.
  Registro devedorPorNome(String nome) {
    final n = nome.trim();
    for (final d in devedores) {
      if (d.nome.trim().toLowerCase() == n.toLowerCase()) return d;
    }
    final novo = Registro(id: novoId(), nome: n);
    devedores.add(novo);
    return novo;
  }

  Future<Registro> novoCofre(String nome) async {
    final c = Registro(id: novoId(), nome: nome.trim());
    cofres.add(c);
    await _salvar();
    return c;
  }

  Future<void> adicionarMovimento(Registro r, Movimento m) async {
    r.movs.add(m);
    await _salvar();
  }

  Future<void> excluirMovimento(Registro r, Movimento m) async {
    r.movs.removeWhere((x) => x.id == m.id);
    await _salvar();
  }

  /// Salva depois de editar um movimento ou renomear algo.
  Future<void> atualizar() => _salvar();

  Future<void> excluirDevedor(Registro r) async {
    devedores.removeWhere((x) => x.id == r.id);
    await _salvar();
  }

  Future<void> excluirCofre(Registro r) async {
    cofres.removeWhere((x) => x.id == r.id);
    await _salvar();
  }
}

/// Instância única usada pelo app todo.
final dados = Dados();
