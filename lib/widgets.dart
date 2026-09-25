import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dados.dart';
import 'formato.dart';
import 'modelos.dart';
import 'tema.dart';

/// Mostra o valor ou "••••" se o usuário escondeu os valores.
String mostrar(int centavos) => dados.ocultarValores ? 'R\$ ••••' : moeda(centavos);

/// Uma linha de qualquer extrato.
class ItemExtrato {
  final String id;
  final String titulo;
  final String subtitulo;
  final int valor;
  final String sinal; // '+', '−' ou ''
  final DateTime data;
  final IconData icone;
  final Color cor;
  final bool apagado;
  final VoidCallback? aoTocar;
  final Widget? acao;

  ItemExtrato({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.sinal,
    required this.data,
    required this.icone,
    required this.cor,
    this.apagado = false,
    this.aoTocar,
    this.acao,
  });
}

/// Ordena da data mais recente para a mais antiga (e, no mesmo dia,
/// do último lançado para o primeiro).
void ordenarRecentes(List<ItemExtrato> itens) {
  itens.sort((a, b) {
    final c = b.data.compareTo(a.data);
    if (c != 0) return c;
    return b.id.compareTo(a.id);
  });
}

class LinhaExtrato extends StatelessWidget {
  final ItemExtrato item;
  const LinhaExtrato(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    final i = item;
    final corValor = i.apagado ? Cores.texto2 : i.cor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Cores.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: i.aoTocar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: i.cor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(i.icone, color: i.cor, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Cores.texto),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        i.subtitulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: Cores.texto2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dados.ocultarValores
                      ? '••••'
                      : '${i.sinal.isEmpty ? '' : '${i.sinal} '}${moeda(i.valor)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: corValor,
                  ),
                ),
                if (i.acao != null) i.acao! else const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lista com cabeçalho de mês ("Setembro de 2026") entre os grupos.
class ListaExtrato extends StatelessWidget {
  final List<ItemExtrato> itens;
  final String vazio;
  final Widget? topo;
  final String chave;

  const ListaExtrato({
    super.key,
    required this.itens,
    required this.vazio,
    required this.chave,
    this.topo,
  });

  @override
  Widget build(BuildContext context) {
    final linhas = <Widget>[];
    if (topo != null) linhas.add(topo!);
    if (itens.isEmpty) {
      linhas.add(Vazio(vazio));
    } else {
      String? mesAtual;
      for (final i in itens) {
        final m = mesAno(i.data);
        if (m != mesAtual) {
          mesAtual = m;
          linhas.add(Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Text(m.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Cores.texto3)),
          ));
        }
        linhas.add(LinhaExtrato(i));
      }
    }
    linhas.add(const SizedBox(height: 110));
    return ListView(
      key: PageStorageKey(chave),
      padding: const EdgeInsets.only(top: 4),
      children: linhas,
    );
  }
}

class Vazio extends StatelessWidget {
  final String texto;
  const Vazio(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 44, color: Cores.texto3),
          const SizedBox(height: 12),
          Text(texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Cores.texto2, fontSize: 14)),
        ],
      ),
    );
  }
}

/// Campo grande de valor em reais.
class CampoValor extends StatelessWidget {
  final TextEditingController controle;
  final String prefixo;
  final Color cor;
  final bool autofoco;

  const CampoValor({
    super.key,
    required this.controle,
    required this.prefixo,
    required this.cor,
    this.autofoco = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(prefixo,
            style: TextStyle(
                fontSize: 30, fontWeight: FontWeight.w700, color: cor)),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: controle,
            autofocus: autofoco,
            keyboardType: TextInputType.number,
            inputFormatters: [FormatoCentavos()],
            cursorColor: cor,
            style: TextStyle(
                fontSize: 38, fontWeight: FontWeight.w800, color: cor),
            decoration: const InputDecoration(
              filled: false,
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

/// Botão de data com atalhos "Hoje" e "Ontem".
class SeletorData extends StatelessWidget {
  final DateTime data;
  final ValueChanged<DateTime> aoMudar;
  final Color cor;

  const SeletorData({
    super.key,
    required this.data,
    required this.aoMudar,
    this.cor = Cores.roxo,
  });

  @override
  Widget build(BuildContext context) {
    final hoje = soDia(DateTime.now());
    final ontem = hoje.subtract(const Duration(days: 1));
    Widget atalho(String t, DateTime d) {
      final sel = soDia(data) == d;
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: ChoiceChip(
          label: Text(t),
          selected: sel,
          showCheckmark: false,
          selectedColor: cor.withOpacity(0.22),
          side: BorderSide(color: sel ? cor : Cores.borda),
          labelStyle: TextStyle(color: sel ? cor : Cores.texto2),
          onSelected: (_) => aoMudar(d),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Material(
            color: Cores.card2,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: data,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  helpText: 'Escolha a data',
                  cancelText: 'Cancelar',
                  confirmText: 'OK',
                );
                if (d != null) aoMudar(soDia(d));
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: cor, size: 20),
                    const SizedBox(width: 10),
                    Text(dataBr(data),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Cores.texto)),
                  ],
                ),
              ),
            ),
          ),
        ),
        atalho('Hoje', hoje),
        atalho('Ontem', ontem),
      ],
    );
  }
}

/// Botão grande colorido de salvar.
class BotaoPrincipal extends StatelessWidget {
  final String texto;
  final Color cor;
  final VoidCallback? aoTocar;
  final IconData? icone;

  const BotaoPrincipal({
    super.key,
    required this.texto,
    required this.cor,
    required this.aoTocar,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: cor,
          foregroundColor: const Color(0xFF0B0B11),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        onPressed: aoTocar,
        icon: Icon(icone ?? Icons.check_rounded),
        label: Text(texto),
      ),
    );
  }
}

Future<bool> confirmar(BuildContext context, String titulo, String texto,
    {String sim = 'Excluir', Color cor = Cores.vermelho}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cor),
          onPressed: () => Navigator.pop(c, true),
          child: Text(sim),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> pedirTexto(BuildContext context, String titulo,
    {String inicial = '', String rotulo = 'Nome'}) async {
  final ctrl = TextEditingController(text: inicial);
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: rotulo),
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text),
            child: const Text('Salvar')),
      ],
    ),
  );
  if (r == null || r.trim().isEmpty) return null;
  return r.trim();
}

void aviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

void vibrarLeve() => HapticFeedback.lightImpact();

// ------------------------------------------------------------------------
// Janela (bottom sheet) para lançar um movimento: empréstimo, pagamento,
// depósito ou retirada de cofre.

class ResultadoMovimento {
  final int valor;
  final DateTime data;
  final String descricao;
  final String nome;
  final bool afetaLivre;
  final bool excluir;

  ResultadoMovimento({
    this.valor = 0,
    DateTime? data,
    this.descricao = '',
    this.nome = '',
    this.afetaLivre = true,
    this.excluir = false,
  }) : data = data ?? DateTime.now();
}

Future<ResultadoMovimento?> abrirMovimento(
  BuildContext context, {
  required String titulo,
  required Color cor,
  String prefixo = 'R\$',
  String botao = 'Salvar',
  Movimento? inicial,
  int? maximo,
  String avisoMaximo = 'Valor maior que o permitido.',
  bool pedirNome = false,
  String rotuloNome = 'Nome',
  List<String> sugestoes = const [],
  bool mostrarAfetaLivre = false,
  bool permitirZero = false,
  bool permitirExcluir = false,
}) {
  return showModalBottomSheet<ResultadoMovimento>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _JanelaMovimento(
      titulo: titulo,
      cor: cor,
      prefixo: prefixo,
      botao: botao,
      inicial: inicial,
      maximo: maximo,
      avisoMaximo: avisoMaximo,
      pedirNome: pedirNome,
      rotuloNome: rotuloNome,
      sugestoes: sugestoes,
      mostrarAfetaLivre: mostrarAfetaLivre,
      permitirZero: permitirZero,
      permitirExcluir: permitirExcluir,
    ),
  );
}

class _JanelaMovimento extends StatefulWidget {
  final String titulo, prefixo, botao, avisoMaximo, rotuloNome;
  final Color cor;
  final Movimento? inicial;
  final int? maximo;
  final bool pedirNome, mostrarAfetaLivre, permitirZero, permitirExcluir;
  final List<String> sugestoes;

  const _JanelaMovimento({
    required this.titulo,
    required this.cor,
    required this.prefixo,
    required this.botao,
    required this.inicial,
    required this.maximo,
    required this.avisoMaximo,
    required this.pedirNome,
    required this.rotuloNome,
    required this.sugestoes,
    required this.mostrarAfetaLivre,
    required this.permitirZero,
    required this.permitirExcluir,
  });

  @override
  State<_JanelaMovimento> createState() => _JanelaMovimentoState();
}

class _JanelaMovimentoState extends State<_JanelaMovimento> {
  late final TextEditingController _valor;
  late final TextEditingController _desc;
  final _nome = TextEditingController();
  late DateTime _data;
  late bool _afetaLivre;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final i = widget.inicial;
    _valor = TextEditingController(text: numero(i?.valor ?? 0));
    _desc = TextEditingController(text: i?.descricao ?? '');
    _data = soDia(i?.data ?? DateTime.now());
    _afetaLivre = i?.afetaLivre ?? true;
  }

  @override
  void dispose() {
    _valor.dispose();
    _desc.dispose();
    _nome.dispose();
    super.dispose();
  }

  void _salvar() {
    final v = centavosDoTexto(_valor.text);
    if (widget.pedirNome && _nome.text.trim().isEmpty) {
      setState(() => _erro = 'Digite o ${widget.rotuloNome.toLowerCase()}.');
      return;
    }
    if (v <= 0 && !widget.permitirZero) {
      setState(() => _erro = 'Digite um valor.');
      return;
    }
    if (widget.maximo != null && v > widget.maximo!) {
      setState(() => _erro = widget.avisoMaximo);
      return;
    }
    Navigator.pop(
      context,
      ResultadoMovimento(
        valor: v,
        data: _data,
        descricao: _desc.text.trim(),
        nome: _nome.text.trim(),
        afetaLivre: _afetaLivre,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(w.titulo,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                if (w.permitirExcluir)
                  IconButton(
                    tooltip: 'Excluir',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Cores.vermelho),
                    onPressed: () => Navigator.pop(
                        context, ResultadoMovimento(excluir: true)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (w.pedirNome) ...[
              TextField(
                controller: _nome,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: w.rotuloNome),
                onChanged: (_) => setState(() {}),
              ),
              if (w.sugestoes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final s in w.sugestoes)
                      ActionChip(
                        label: Text(s),
                        onPressed: () => setState(() => _nome.text = s),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
            ],
            CampoValor(
              controle: _valor,
              prefixo: w.prefixo,
              cor: w.cor,
              autofoco: !w.pedirNome && w.inicial == null,
            ),
            if (w.maximo != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Máximo: ${moeda(w.maximo!)}',
                    style:
                        const TextStyle(color: Cores.texto2, fontSize: 12.5)),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _desc,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(labelText: 'Descrição (opcional)'),
            ),
            const SizedBox(height: 14),
            SeletorData(
              data: _data,
              cor: w.cor,
              aoMudar: (d) => setState(() => _data = d),
            ),
            if (w.mostrarAfetaLivre) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _afetaLivre,
                activeColor: w.cor,
                onChanged: (v) => setState(() => _afetaLivre = v),
                title: const Text('Tirar do meu dinheiro livre'),
                subtitle: const Text(
                    'Desligue só para registrar um empréstimo antigo, '
                    'que já saiu do seu dinheiro antes de usar o app.',
                    style: TextStyle(fontSize: 12.5)),
              ),
            ],
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_erro!,
                    style: const TextStyle(color: Cores.vermelho)),
              ),
            const SizedBox(height: 18),
            BotaoPrincipal(texto: w.botao, cor: w.cor, aoTocar: _salvar),
          ],
        ),
      ),
    );
  }
}
