import 'package:flutter/material.dart';

import '../dados.dart';
import '../formato.dart';
import '../modelos.dart';
import '../notificacoes.dart';
import '../tema.dart';
import '../widgets.dart';

enum _Situacao { concluido, pendente, assinatura }

/// Tela de nova/editar Entrada, Saída, Rendimento ou Assinatura.
class LancamentoPage extends StatefulWidget {
  final TipoTransacao tipo;
  final Transacao? editar;
  final Assinatura? editarAssinatura;
  final bool comecarPendente;
  final bool comecarAssinatura;

  const LancamentoPage({
    super.key,
    required this.tipo,
    this.editar,
    this.editarAssinatura,
    this.comecarPendente = false,
    this.comecarAssinatura = false,
  });

  @override
  State<LancamentoPage> createState() => _LancamentoPageState();
}

class _LancamentoPageState extends State<LancamentoPage> {
  late final TextEditingController _valor;
  late final TextEditingController _desc;
  late DateTime _data;
  late _Situacao _sit;
  int _dia = DateTime.now().day;
  bool _lembrete = true;
  bool _jaPagueiEsteMes = false;

  bool get _editando => widget.editar != null || widget.editarAssinatura != null;

  Color get _cor => switch (widget.tipo) {
        TipoTransacao.entrada => Cores.verde,
        TipoTransacao.saida => Cores.vermelho,
        TipoTransacao.rendimento => Cores.ciano,
      };

  String get _nomeTipo => switch (widget.tipo) {
        TipoTransacao.entrada => 'Entrada',
        TipoTransacao.saida => 'Saída',
        TipoTransacao.rendimento => 'Rendimento',
      };

  @override
  void initState() {
    super.initState();
    final t = widget.editar;
    final a = widget.editarAssinatura;
    _valor = TextEditingController(text: numero(t?.valor ?? a?.valor ?? 0));
    _desc = TextEditingController(text: t?.descricao ?? a?.descricao ?? '');
    _data = soDia(t?.data ?? DateTime.now());
    if (a != null) {
      _sit = _Situacao.assinatura;
      _dia = a.dia;
      _lembrete = a.lembrete;
    } else if (t != null) {
      _sit = t.pendente ? _Situacao.pendente : _Situacao.concluido;
    } else {
      _sit = widget.comecarAssinatura
          ? _Situacao.assinatura
          : (widget.comecarPendente ? _Situacao.pendente : _Situacao.concluido);
    }
  }

  @override
  void dispose() {
    _valor.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final v = centavosDoTexto(_valor.text);
    if (v <= 0) {
      aviso(context, 'Digite um valor maior que zero.');
      return;
    }
    final desc = _desc.text.trim().isEmpty ? _nomeTipo : _desc.text.trim();

    if (_sit == _Situacao.assinatura) {
      final a = widget.editarAssinatura ??
          Assinatura(id: novoId(), descricao: desc, valor: v, dia: _dia);
      a
        ..descricao = desc
        ..valor = v
        ..dia = _dia
        ..lembrete = _lembrete;
      if (_lembrete) await Notificacoes.pedirPermissao();
      await dados.salvarAssinatura(a);
      if (_jaPagueiEsteMes && !a.pagoNoMes(_data)) {
        await dados.pagarAssinatura(a, _data);
      }
    } else {
      final status = switch ((widget.tipo, _sit)) {
        (TipoTransacao.entrada, _Situacao.pendente) => StatusTransacao.aReceber,
        (TipoTransacao.entrada, _) => StatusTransacao.recebido,
        (TipoTransacao.saida, _Situacao.pendente) => StatusTransacao.aPagar,
        (TipoTransacao.saida, _) => StatusTransacao.pago,
        (TipoTransacao.rendimento, _) => StatusTransacao.recebido,
      };
      final t = Transacao(
        id: widget.editar?.id ?? novoId(),
        tipo: widget.tipo,
        valor: v,
        descricao: desc,
        data: _data,
        status: status,
      );
      await dados.salvarTransacao(t);
    }
    if (!mounted) return;
    vibrarLeve();
    Navigator.pop(context);
  }

  Future<void> _excluir() async {
    final ok = await confirmar(context, 'Excluir?',
        'Isso apaga este lançamento de vez. Não dá para desfazer.');
    if (!ok) return;
    if (widget.editarAssinatura != null) {
      await dados.excluirAssinatura(widget.editarAssinatura!);
    } else if (widget.editar != null) {
      await dados.excluirTransacao(widget.editar!);
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _chip(String texto, _Situacao s, {IconData? icone}) {
    final sel = _sit == s;
    return ChoiceChip(
      label: Text(texto),
      avatar: icone == null
          ? null
          : Icon(icone, size: 18, color: sel ? const Color(0xFF0B0B11) : Cores.texto2),
      selected: sel,
      showCheckmark: false,
      selectedColor: _cor,
      backgroundColor: Cores.card2,
      side: BorderSide(color: sel ? _cor : Cores.borda),
      labelStyle: TextStyle(
        color: sel ? const Color(0xFF0B0B11) : Cores.texto,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => setState(() => _sit = s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tipo = widget.tipo;
    final String titulo;
    if (widget.editarAssinatura != null) {
      titulo = 'Editar Assinatura';
    } else if (_editando) {
      titulo = 'Editar $_nomeTipo';
    } else {
      titulo = tipo == TipoTransacao.rendimento ? 'Novo Rendimento' : 'Nova $_nomeTipo';
    }

    // Uma assinatura já existente não vira transação comum e vice-versa.
    final podeTrocarSituacao = widget.editarAssinatura == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          if (_editando)
            IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Cores.vermelho),
              onPressed: _excluir,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            _sit == _Situacao.assinatura ? 'Valor mensal' : 'Valor',
            style: const TextStyle(color: Cores.texto2),
          ),
          const SizedBox(height: 6),
          CampoValor(
            controle: _valor,
            prefixo: tipo == TipoTransacao.saida ? '− R\$' : '+ R\$',
            cor: _cor,
            autofoco: !_editando,
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _desc,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Descrição'),
          ),
          const SizedBox(height: 18),
          if (tipo != TipoTransacao.rendimento && podeTrocarSituacao) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tipo == TipoTransacao.entrada
                  ? [
                      _chip('Recebido', _Situacao.concluido,
                          icone: Icons.check_rounded),
                      _chip('A receber', _Situacao.pendente,
                          icone: Icons.schedule_rounded),
                    ]
                  : [
                      _chip('Pago', _Situacao.concluido,
                          icone: Icons.check_rounded),
                      _chip('A pagar', _Situacao.pendente,
                          icone: Icons.schedule_rounded),
                      if (widget.editar == null)
                        _chip('Assinatura', _Situacao.assinatura,
                            icone: Icons.autorenew_rounded),
                    ],
            ),
            const SizedBox(height: 18),
          ],
          if (_sit != _Situacao.assinatura) ...[
            Text(
              _sit == _Situacao.pendente
                  ? (tipo == TipoTransacao.entrada
                      ? 'Data prevista para receber'
                      : 'Data de vencimento')
                  : 'Data',
              style: const TextStyle(color: Cores.texto2),
            ),
            const SizedBox(height: 8),
            SeletorData(
              data: _data,
              cor: _cor,
              aoMudar: (d) => setState(() => _data = d),
            ),
          ] else
            _camposAssinatura(),
          const SizedBox(height: 28),
          BotaoPrincipal(texto: 'Salvar', cor: _cor, aoTocar: _salvar),
        ],
      ),
    );
  }

  Widget _camposAssinatura() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dia do vencimento (todo mês)',
            style: TextStyle(color: Cores.texto2)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Cores.card2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _dia,
              isExpanded: true,
              dropdownColor: Cores.card2,
              menuMaxHeight: 360,
              items: [
                for (var d = 1; d <= 31; d++)
                  DropdownMenuItem(value: d, child: Text('Dia $d')),
              ],
              onChanged: (v) => setState(() => _dia = v ?? _dia),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _lembrete,
          activeColor: _cor,
          onChanged: (v) => setState(() => _lembrete = v),
          title: const Text('Lembrete no dia do vencimento'),
          subtitle: const Text('Notificação às 9h', style: TextStyle(fontSize: 12.5)),
        ),
        if (widget.editarAssinatura == null ||
            !widget.editarAssinatura!.pagoNoMes(_data)) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _jaPagueiEsteMes,
            activeColor: _cor,
            onChanged: (v) => setState(() => _jaPagueiEsteMes = v ?? false),
            title: const Text('Já paguei este mês'),
            subtitle: const Text('Lança como saída paga na data abaixo',
                style: TextStyle(fontSize: 12.5)),
          ),
          if (_jaPagueiEsteMes)
            SeletorData(
              data: _data,
              cor: _cor,
              aoMudar: (d) => setState(() => _data = d),
            ),
        ],
      ],
    );
  }
}
