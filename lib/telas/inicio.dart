import 'package:flutter/material.dart';

import '../dados.dart';
import '../formato.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'cofres.dart';
import 'configuracoes.dart';
import 'dividas.dart';
import 'lancamento.dart';

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage>
    with SingleTickerProviderStateMixin {
  static const _abas = [
    'Geral',
    'Entradas',
    'Saídas',
    'Rendimentos',
    'A Receber',
    'A Pagar',
    'Assinaturas',
  ];
  late final TabController _tab =
      TabController(length: _abas.length, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ navegação

  void _abrir(Widget pagina) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => pagina));

  void _novo(TipoTransacao tipo, {bool pendente = false}) =>
      _abrir(LancamentoPage(tipo: tipo, comecarPendente: pendente));

  String get _saudacao {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Bom dia';
    if (h >= 12 && h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  // ------------------------------------------------------ itens do extrato

  static const _rotuloStatus = {
    StatusTransacao.recebido: 'Recebido',
    StatusTransacao.aReceber: 'A receber',
    StatusTransacao.pago: 'Pago',
    StatusTransacao.aPagar: 'A pagar',
  };

  ItemExtrato _itemTransacao(Transacao t) {
    final (cor, icone, sinal) = switch (t.tipo) {
      TipoTransacao.entrada => (Cores.verde, Icons.south_west_rounded, '+'),
      TipoTransacao.saida => (Cores.vermelho, Icons.north_east_rounded, '−'),
      TipoTransacao.rendimento => (Cores.ciano, Icons.trending_up_rounded, '+'),
    };
    final hoje = soDia(DateTime.now());
    final atrasado = t.pendente && t.data.isBefore(hoje);
    final partes = <String>[
      dataBr(t.data),
      if (t.tipo == TipoTransacao.rendimento)
        'Rendimento'
      else
        _rotuloStatus[t.status]!,
      if (atrasado) 'atrasado',
    ];
    return ItemExtrato(
      id: t.id,
      titulo: t.descricao,
      subtitulo: partes.join(' · '),
      valor: t.valor,
      sinal: sinal,
      data: t.data,
      icone: t.pendente ? Icons.schedule_rounded : icone,
      cor: t.pendente ? (atrasado ? Cores.laranja : cor.withOpacity(0.75)) : cor,
      apagado: t.pendente,
      aoTocar: () => _abrir(LancamentoPage(tipo: t.tipo, editar: t)),
      acao: t.pendente
          ? IconButton(
              tooltip: t.tipo == TipoTransacao.entrada
                  ? 'Marcar como recebido'
                  : 'Marcar como pago',
              icon: Icon(Icons.check_circle_outline_rounded, color: cor),
              onPressed: () => _concluir(t),
            )
          : null,
    );
  }

  Future<void> _concluir(Transacao t) async {
    final entrada = t.tipo == TipoTransacao.entrada;
    final escolha = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(entrada ? 'Marcar como recebido?' : 'Marcar como pago?'),
        content: Text(
            '${t.descricao} · ${moeda(t.valor)}\n\nEm qual data isso aconteceu?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, 'prevista'),
              child: Text('Em ${dataBr(t.data)}')),
          FilledButton(
              onPressed: () => Navigator.pop(c, 'hoje'),
              child: const Text('Hoje')),
        ],
      ),
    );
    if (escolha == null) return;
    await dados.concluir(t, data: escolha == 'hoje' ? DateTime.now() : null);
    vibrarLeve();
    if (mounted) aviso(context, entrada ? 'Marcado como recebido.' : 'Marcado como pago.');
  }

  List<ItemExtrato> _itensDividas() {
    final itens = <ItemExtrato>[];
    for (final d in dados.devedores) {
      for (final m in d.movs) {
        itens.add(ItemExtrato(
          id: m.id,
          titulo: m.positivo ? 'Empréstimo para ${d.nome}' : '${d.nome} pagou',
          subtitulo: [
            dataBr(m.data),
            'Dívida',
            if (m.descricao.isNotEmpty) m.descricao,
          ].join(' · '),
          valor: m.valor,
          sinal: m.positivo ? (m.afetaLivre ? '−' : '') : '+',
          data: m.data,
          icone: m.positivo ? Icons.handshake_rounded : Icons.payments_rounded,
          cor: Cores.azul,
          aoTocar: () => _abrir(DevedorPage(id: d.id)),
        ));
      }
    }
    return itens;
  }

  List<ItemExtrato> _filtrar(bool Function(Transacao t) f,
      {bool comDividas = false}) {
    final itens = dados.transacoes.where(f).map(_itemTransacao).toList();
    if (comDividas) itens.addAll(_itensDividas());
    ordenarRecentes(itens);
    return itens;
  }

  Widget _totalTopo(String rotulo, int valor, Color cor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Text(rotulo, style: const TextStyle(color: Cores.texto2)),
          const Spacer(),
          Text(mostrar(valor),
              style: TextStyle(
                  color: cor, fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ abas

  Widget _aba(int i) {
    switch (i) {
      case 0:
        return ListaExtrato(
          chave: 'geral',
          itens: _filtrar((_) => true, comDividas: true),
          vazio: 'Nada por aqui ainda.\n\n'
              'Dica: comece lançando o dinheiro que você tem hoje como uma '
              'Entrada chamada "Saldo inicial".',
        );
      case 1:
        return ListaExtrato(
          chave: 'entradas',
          itens: _filtrar((t) => t.tipo == TipoTransacao.entrada),
          vazio: 'Nenhuma entrada.',
        );
      case 2:
        return ListaExtrato(
          chave: 'saidas',
          itens: _filtrar((t) => t.tipo == TipoTransacao.saida),
          vazio: 'Nenhuma saída.',
        );
      case 3:
        return ListaExtrato(
          chave: 'rendimentos',
          topo: _totalTopo('Total investido', dados.investido, Cores.ciano),
          itens: _filtrar((t) => t.tipo == TipoTransacao.rendimento),
          vazio: 'Nenhum rendimento.',
        );
      case 4:
        return ListaExtrato(
          chave: 'areceber',
          topo: _totalTopo('Total a receber', dados.aReceber, Cores.verde),
          itens: _filtrar((t) => t.status == StatusTransacao.aReceber),
          vazio: 'Nada a receber.',
        );
      case 5:
        return ListaExtrato(
          chave: 'apagar',
          topo: _totalTopo('Total a pagar', dados.aPagar, Cores.vermelho),
          itens: _filtrar((t) => t.status == StatusTransacao.aPagar),
          vazio: 'Nenhuma conta a pagar.',
        );
      default:
        return _abaAssinaturas();
    }
  }

  Widget _abaAssinaturas() {
    final hoje = DateTime.now();
    final lista = [...dados.assinaturas]..sort((a, b) => a.dia.compareTo(b.dia));
    final total = lista.fold(0, (s, a) => s + a.valor);
    return ListView(
      key: const PageStorageKey('assinaturas'),
      padding: const EdgeInsets.only(top: 4, bottom: 110),
      children: [
        _totalTopo('Total por mês', total, Cores.roxo),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Cores.roxo,
              side: const BorderSide(color: Cores.borda),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _abrir(const LancamentoPage(
                tipo: TipoTransacao.saida, comecarAssinatura: true)),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nova assinatura'),
          ),
        ),
        if (lista.isEmpty) const Vazio('Nenhuma assinatura cadastrada.'),
        for (final a in lista)
          LinhaExtrato(ItemExtrato(
            id: a.id,
            titulo: a.descricao,
            subtitulo: [
              'Todo dia ${a.dia}',
              a.pagoNoMes(hoje) ? 'Pago este mês ✓' : 'Falta pagar este mês',
              if (a.lembrete) '🔔',
            ].join(' · '),
            valor: a.valor,
            sinal: '−',
            data: hoje,
            icone: Icons.autorenew_rounded,
            cor: a.pagoNoMes(hoje) ? Cores.texto2 : Cores.roxo,
            apagado: a.pagoNoMes(hoje),
            aoTocar: () => _abrir(LancamentoPage(
                tipo: TipoTransacao.saida, editarAssinatura: a)),
            acao: a.pagoNoMes(hoje)
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.check_circle_rounded,
                        color: Cores.verde, size: 22),
                  )
                : IconButton(
                    tooltip: 'Pagar',
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        color: Cores.roxo),
                    onPressed: () => _pagarAssinatura(a),
                  ),
          )),
      ],
    );
  }

  Future<void> _pagarAssinatura(Assinatura a) async {
    final r = await abrirMovimento(
      context,
      titulo: 'Pagar ${a.descricao}',
      cor: Cores.vermelho,
      prefixo: '− R\$',
      botao: 'Pagar',
      inicial: Movimento(
        id: '',
        positivo: false,
        valor: a.valor,
        data: DateTime.now(),
      ),
    );
    if (r == null) return;
    await dados.pagarAssinatura(a, r.data,
        valor: r.valor, descricao: r.descricao);
    if (mounted) aviso(context, '${a.descricao} lançada como saída paga.');
  }

  // ------------------------------------------------------------ topo

  Widget _cabecalho() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: dados.nome.isEmpty
                  ? () async {
                      final n = await pedirTexto(
                          context, 'Como quer ser chamado?');
                      if (n != null) await dados.setNome(n);
                    }
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_saudacao,',
                      style:
                          const TextStyle(color: Cores.texto2, fontSize: 14)),
                  Text(
                    dados.nome.isEmpty ? 'toque para pôr seu nome' : dados.nome,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: dados.ocultarValores ? 'Mostrar valores' : 'Esconder valores',
            icon: Icon(
              dados.ocultarValores
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: Cores.texto2,
            ),
            onPressed: () => dados.setOcultar(!dados.ocultarValores),
          ),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_rounded, color: Cores.texto2),
            onPressed: () => _abrir(const ConfiguracoesPage()),
          ),
        ],
      ),
    );
  }

  Widget _cartaoSaldo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF3B1F7A), Color(0xFF1A1433), Color(0xFF14141C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x33A78BFA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Saldo geral',
                  style: TextStyle(color: Color(0xFFCFC3F5), fontSize: 14)),
              const SizedBox(width: 4),
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _abrir(const ConfiguracoesPage()),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFFCFC3F5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              mostrar(dados.saldoGeral),
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat('Livre', dados.livre, Cores.verde, () => _tab.animateTo(0)),
              _Stat('Investido', dados.investido, Cores.ciano,
                  () => _tab.animateTo(3)),
              _Stat('Na rua', dados.naRua, Cores.azul,
                  () => _abrir(const DividasPage())),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Stat('A receber', dados.aReceber, const Color(0xFF86EFAC),
                  () => _tab.animateTo(4)),
              _Stat('A pagar', dados.aPagar, Cores.vermelho,
                  () => _tab.animateTo(5)),
              _Stat('Cofres', dados.totalCofres, Cores.amarelo,
                  () => _abrir(const CofresPage()),
                  icone: Icons.lock_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _acoes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Acao('Entrada', Icons.south_west_rounded, Cores.verde,
              () => _novo(TipoTransacao.entrada)),
          _Acao('Saída', Icons.north_east_rounded, Cores.vermelho,
              () => _novo(TipoTransacao.saida)),
          _Acao('Rendimento', Icons.trending_up_rounded, Cores.ciano,
              () => _novo(TipoTransacao.rendimento)),
          _Acao('Dívidas', Icons.handshake_rounded, Cores.azul,
              () => _abrir(const DividasPage())),
          _Acao('Cofres', Icons.lock_rounded, Cores.amarelo,
              () => _abrir(const CofresPage())),
        ],
      ),
    );
  }

  TabBar get _tabBar => TabBar(
        controller: _tab,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Cores.roxo.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Cores.roxo.withOpacity(0.5)),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Cores.texto2,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        splashBorderRadius: BorderRadius.circular(20),
        tabs: [for (final a in _abas) Tab(text: a, height: 38)],
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dados,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(child: _cabecalho()),
              SliverToBoxAdapter(child: _cartaoSaldo()),
              SliverToBoxAdapter(child: _acoes()),
              SliverPersistentHeader(
                pinned: true,
                delegate: _AbasFixas(_tabBar),
              ),
            ],
            body: TabBarView(
              controller: _tab,
              children: [for (var i = 0; i < _abas.length; i++) _aba(i)],
            ),
          ),
        ),
      ),
    );
  }
}

class _AbasFixas extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _AbasFixas(this.tabBar);

  static const _altura = 54.0;

  @override
  double get minExtent => _altura;
  @override
  double get maxExtent => _altura;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Cores.fundo,
      alignment: Alignment.center,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _AbasFixas oldDelegate) => true;
}

class _Stat extends StatelessWidget {
  final String rotulo;
  final int valor;
  final Color cor;
  final VoidCallback aoTocar;
  final IconData? icone;

  const _Stat(this.rotulo, this.valor, this.cor, this.aoTocar, {this.icone});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: cor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(rotulo,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFFB9B4CC), fontSize: 12)),
                  ),
                  if (icone != null) ...[
                    const SizedBox(width: 3),
                    Icon(icone, size: 11, color: const Color(0xFFB9B4CC)),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  mostrar(valor),
                  style: TextStyle(
                      color: cor, fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Acao extends StatelessWidget {
  final String rotulo;
  final IconData icone;
  final Color cor;
  final VoidCallback aoTocar;
  const _Acao(this.rotulo, this.icone, this.cor, this.aoTocar);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: cor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cor.withOpacity(0.28)),
              ),
              child: Icon(icone, color: cor, size: 24),
            ),
            const SizedBox(height: 6),
            Text(rotulo,
                style: const TextStyle(fontSize: 11.5, color: Cores.texto2)),
          ],
        ),
      ),
    );
  }
}
