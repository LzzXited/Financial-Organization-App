import 'package:flutter/material.dart';

import '../dados.dart';
import '../formato.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';

/// Lança um empréstimo novo. Se o nome já existir, soma na dívida da pessoa.
Future<void> novoEmprestimo(BuildContext context, {Registro? pessoa}) async {
  final r = await abrirMovimento(
    context,
    titulo: pessoa == null ? 'Novo empréstimo' : 'Emprestar mais para ${pessoa.nome}',
    cor: Cores.azul,
    botao: 'Emprestar',
    pedirNome: pessoa == null,
    rotuloNome: 'Nome da pessoa',
    sugestoes: pessoa == null ? dados.devedores.map((d) => d.nome).toList() : const [],
    mostrarAfetaLivre: true,
  );
  if (r == null) return;
  final p = pessoa ?? dados.devedorPorNome(r.nome);
  await dados.adicionarMovimento(
    p,
    Movimento(
      id: novoId(),
      positivo: true,
      valor: r.valor,
      data: r.data,
      descricao: r.descricao,
      afetaLivre: r.afetaLivre,
    ),
  );
  if (context.mounted) aviso(context, 'Empréstimo de ${moeda(r.valor)} para ${p.nome} salvo.');
}

class DividasPage extends StatelessWidget {
  const DividasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dados,
      builder: (context, _) {
        final ativos = dados.devedores.where((d) => d.saldo > 0).toList()
          ..sort((a, b) => b.saldo.compareTo(a.saldo));
        final quitados = dados.devedores.where((d) => d.saldo <= 0).toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));
        return Scaffold(
          appBar: AppBar(title: const Text('Dívidas')),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Cores.azul,
            foregroundColor: Cores.fundo,
            onPressed: () => novoEmprestimo(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Novo empréstimo',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              ResumoCard(
                titulo: 'Total na rua (me devem)',
                valor: dados.naRua,
                cor: Cores.azul,
                nota: 'Empréstimo não aumenta nem diminui seu saldo geral: '
                    'o dinheiro continua sendo seu.',
              ),
              if (ativos.isEmpty && quitados.isEmpty)
                const Vazio('Ninguém te deve nada.\nToque em "Novo empréstimo" para registrar.'),
              for (final d in ativos) _LinhaPessoa(d),
              if (quitados.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 6),
                  child: Text('QUITADOS',
                      style: TextStyle(
                          fontSize: 11.5,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: Cores.texto3)),
                ),
                for (final d in quitados) _LinhaPessoa(d),
              ],
            ],
          ),
        );
      },
    );
  }
}

class ResumoCard extends StatelessWidget {
  final String titulo;
  final int valor;
  final Color cor;
  final String? nota;
  const ResumoCard({required this.titulo, required this.valor, required this.cor, this.nota});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [cor.withOpacity(0.28), cor.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: cor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(color: cor, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(mostrar(valor),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          ),
          if (nota != null) ...[
            const SizedBox(height: 8),
            Text(nota!, style: const TextStyle(color: Cores.texto2, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}

class _LinhaPessoa extends StatelessWidget {
  final Registro d;
  const _LinhaPessoa(this.d);

  @override
  Widget build(BuildContext context) {
    final quitado = d.saldo <= 0;
    final ultima = d.ultimaData;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Cores.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => DevedorPage(id: d.id))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: Cores.azul.withOpacity(quitado ? 0.08 : 0.18),
                  child: Text(
                    d.nome.isEmpty ? '?' : d.nome.characters.first.toUpperCase(),
                    style: TextStyle(
                        color: quitado ? Cores.texto3 : Cores.azul,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.nome,
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        quitado
                            ? 'Quitado'
                            : 'Emprestado ${mostrar(d.totalPositivo)} · pagou ${mostrar(d.totalNegativo)}',
                        style: const TextStyle(fontSize: 12.5, color: Cores.texto2),
                      ),
                      if (ultima != null)
                        Text('Último movimento: ${dataBr(ultima)}',
                            style: const TextStyle(fontSize: 11.5, color: Cores.texto3)),
                    ],
                  ),
                ),
                Text(mostrar(d.saldo),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: quitado ? Cores.texto3 : Cores.azul)),
                const Icon(Icons.chevron_right_rounded, color: Cores.texto3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Detalhe de uma pessoa: emprestar mais, receber pagamento e histórico.
class DevedorPage extends StatelessWidget {
  final String id;
  const DevedorPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dados,
      builder: (context, _) {
        final d = dados.devedor(id);
        if (d == null) {
          return Scaffold(appBar: AppBar(), body: const Vazio('Pessoa não encontrada.'));
        }
        final movs = [...d.movs]..sort((a, b) {
            final c = b.data.compareTo(a.data);
            return c != 0 ? c : b.id.compareTo(a.id);
          });
        return Scaffold(
          appBar: AppBar(
            title: Text(d.nome),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'renomear') {
                    final n = await pedirTexto(context, 'Renomear', inicial: d.nome);
                    if (n != null) {
                      d.nome = n;
                      await dados.atualizar();
                    }
                  } else if (v == 'excluir') {
                    final ok = await confirmar(context, 'Excluir ${d.nome}?',
                        'Apaga a pessoa e todo o histórico de empréstimos e pagamentos dela. '
                        'Isso muda o seu dinheiro livre.');
                    if (ok) {
                      await dados.excluirDevedor(d);
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'renomear', child: Text('Renomear')),
                  PopupMenuItem(value: 'excluir', child: Text('Excluir pessoa')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              ResumoCard(titulo: 'Falta receber', valor: d.saldo, cor: Cores.azul),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: MiniCard('Emprestado', d.totalPositivo, Cores.azul)),
                    const SizedBox(width: 10),
                    Expanded(child: MiniCard('Já pagou', d.totalNegativo, Cores.verde)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: BotaoAcao(
                        texto: 'Emprestar mais',
                        icone: Icons.add_rounded,
                        cor: Cores.azul,
                        aoTocar: () => novoEmprestimo(context, pessoa: d),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BotaoAcao(
                        texto: 'Receber',
                        icone: Icons.payments_rounded,
                        cor: Cores.verde,
                        aoTocar: d.saldo <= 0
                            ? null
                            : () => _receber(context, d),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 22, 20, 6),
                child: Text('HISTÓRICO',
                    style: TextStyle(
                        fontSize: 11.5,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Cores.texto3)),
              ),
              if (movs.isEmpty) const Vazio('Nenhum movimento ainda.'),
              for (final m in movs)
                LinhaExtrato(ItemExtrato(
                  id: m.id,
                  titulo: m.positivo ? 'Empréstimo' : 'Pagamento recebido',
                  subtitulo: [
                    dataBr(m.data),
                    if (m.descricao.isNotEmpty) m.descricao,
                    if (m.positivo && !m.afetaLivre) 'antigo',
                  ].join(' · '),
                  valor: m.valor,
                  sinal: m.positivo ? '+' : '−',
                  data: m.data,
                  icone: m.positivo ? Icons.north_east_rounded : Icons.south_west_rounded,
                  cor: m.positivo ? Cores.azul : Cores.verde,
                  aoTocar: () => _editar(context, d, m),
                )),
            ],
          ),
        );
      },
    );
  }

  Future<void> _receber(BuildContext context, Registro d) async {
    final r = await abrirMovimento(
      context,
      titulo: 'Receber de ${d.nome}',
      cor: Cores.verde,
      botao: 'Receber',
      maximo: d.saldo,
      avisoMaximo: 'A pessoa só deve ${moeda(d.saldo)}.',
    );
    if (r == null) return;
    await dados.adicionarMovimento(
      d,
      Movimento(
        id: novoId(),
        positivo: false,
        valor: r.valor,
        data: r.data,
        descricao: r.descricao,
      ),
    );
    if (context.mounted) {
      aviso(context, d.saldo <= 0
          ? '${d.nome} quitou a dívida!'
          : 'Pagamento salvo. Falta ${moeda(d.saldo)}.');
    }
  }

  Future<void> _editar(BuildContext context, Registro d, Movimento m) async {
    final r = await abrirMovimento(
      context,
      titulo: m.positivo ? 'Editar empréstimo' : 'Editar pagamento',
      cor: m.positivo ? Cores.azul : Cores.verde,
      inicial: m,
      mostrarAfetaLivre: m.positivo,
      permitirExcluir: true,
      maximo: m.positivo ? null : d.saldo + m.valor,
      avisoMaximo: 'Valor maior do que a pessoa deve.',
    );
    if (r == null) return;
    if (r.excluir) {
      if (!context.mounted) return;
      final ok = await confirmar(context, 'Excluir movimento?', 'Não dá para desfazer.');
      if (ok) await dados.excluirMovimento(d, m);
      return;
    }
    m
      ..valor = r.valor
      ..data = r.data
      ..descricao = r.descricao
      ..afetaLivre = r.afetaLivre;
    await dados.atualizar();
  }
}

class MiniCard extends StatelessWidget {
  final String titulo;
  final int valor;
  final Color cor;
  const MiniCard(this.titulo, this.valor, this.cor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Cores.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Cores.texto2, fontSize: 12.5)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(mostrar(valor),
                style: TextStyle(color: cor, fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class BotaoAcao extends StatelessWidget {
  final String texto;
  final IconData icone;
  final Color cor;
  final VoidCallback? aoTocar;
  const BotaoAcao({required this.texto, required this.icone, required this.cor, this.aoTocar});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: cor.withOpacity(0.16),
          foregroundColor: cor,
          disabledBackgroundColor: Cores.card,
          disabledForegroundColor: Cores.texto3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
        onPressed: aoTocar,
        icon: Icon(icone),
        label: Text(texto),
      ),
    );
  }
}

