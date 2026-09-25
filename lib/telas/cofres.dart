import 'package:flutter/material.dart';

import '../dados.dart';
import '../formato.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets.dart';
import 'dividas.dart' show ResumoCard, MiniCard, BotaoAcao;

/// Cofres de terceiros: dinheiro que estou guardando para outra pessoa.
/// Não entra no meu saldo.
class CofresPage extends StatelessWidget {
  const CofresPage({super.key});

  Future<void> _novo(BuildContext context) async {
    final r = await abrirMovimento(
      context,
      titulo: 'Novo cofre',
      cor: Cores.amarelo,
      botao: 'Criar cofre',
      pedirNome: true,
      rotuloNome: 'De quem é o dinheiro? (ex.: Mãe)',
      permitirZero: true,
    );
    if (r == null) return;
    final c = await dados.novoCofre(r.nome);
    if (r.valor > 0) {
      await dados.adicionarMovimento(
        c,
        Movimento(
          id: novoId(),
          positivo: true,
          valor: r.valor,
          data: r.data,
          descricao: r.descricao,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dados,
      builder: (context, _) {
        final lista = [...dados.cofres]..sort((a, b) => b.saldo.compareTo(a.saldo));
        return Scaffold(
          appBar: AppBar(title: const Text('Cofres de terceiros')),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Cores.amarelo,
            foregroundColor: Cores.fundo,
            onPressed: () => _novo(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Novo cofre', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              ResumoCard(
                titulo: 'Guardado para outras pessoas',
                valor: dados.totalCofres,
                cor: Cores.amarelo,
                nota: 'Esse dinheiro está com você, mas não é seu: '
                    'ele não entra no seu saldo.\n'
                    'Seu livre + cofres = ${mostrar(dados.livre + dados.totalCofres)} em mãos.',
              ),
              if (lista.isEmpty)
                const Vazio('Nenhum cofre ainda.\nCrie um quando alguém pedir para você guardar dinheiro.'),
              for (final c in lista)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Material(
                    color: Cores.card,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => CofrePage(id: c.id))),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Cores.amarelo.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(Icons.lock_rounded, color: Cores.amarelo),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.nome,
                                      style: const TextStyle(
                                          fontSize: 15.5, fontWeight: FontWeight.w600)),
                                  if (c.ultimaData != null)
                                    Text('Último movimento: ${dataBr(c.ultimaData!)}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Cores.texto2)),
                                ],
                              ),
                            ),
                            Text(mostrar(c.saldo),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Cores.amarelo)),
                            const Icon(Icons.chevron_right_rounded, color: Cores.texto3),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class CofrePage extends StatelessWidget {
  final String id;
  const CofrePage({super.key, required this.id});

  Future<void> _mover(BuildContext context, Registro c, bool deposito) async {
    final r = await abrirMovimento(
      context,
      titulo: deposito ? 'Guardar no cofre' : 'Devolver / retirar',
      cor: deposito ? Cores.amarelo : Cores.laranja,
      botao: deposito ? 'Guardar' : 'Retirar',
      maximo: deposito ? null : c.saldo,
      avisoMaximo: 'O cofre só tem ${moeda(c.saldo)}.',
    );
    if (r == null) return;
    await dados.adicionarMovimento(
      c,
      Movimento(
        id: novoId(),
        positivo: deposito,
        valor: r.valor,
        data: r.data,
        descricao: r.descricao,
      ),
    );
  }

  Future<void> _editar(BuildContext context, Registro c, Movimento m) async {
    final r = await abrirMovimento(
      context,
      titulo: m.positivo ? 'Editar depósito' : 'Editar retirada',
      cor: m.positivo ? Cores.amarelo : Cores.laranja,
      inicial: m,
      permitirExcluir: true,
      maximo: m.positivo ? null : c.saldo + m.valor,
      avisoMaximo: 'Valor maior do que tem no cofre.',
    );
    if (r == null) return;
    if (r.excluir) {
      if (!context.mounted) return;
      final ok = await confirmar(context, 'Excluir movimento?', 'Não dá para desfazer.');
      if (ok) await dados.excluirMovimento(c, m);
      return;
    }
    m
      ..valor = r.valor
      ..data = r.data
      ..descricao = r.descricao;
    await dados.atualizar();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dados,
      builder: (context, _) {
        final c = dados.cofre(id);
        if (c == null) {
          return Scaffold(appBar: AppBar(), body: const Vazio('Cofre não encontrado.'));
        }
        final movs = [...c.movs]..sort((a, b) {
            final x = b.data.compareTo(a.data);
            return x != 0 ? x : b.id.compareTo(a.id);
          });
        return Scaffold(
          appBar: AppBar(
            title: Text('Cofre: ${c.nome}'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'renomear') {
                    final n = await pedirTexto(context, 'Renomear cofre', inicial: c.nome);
                    if (n != null) {
                      c.nome = n;
                      await dados.atualizar();
                    }
                  } else if (v == 'excluir') {
                    final ok = await confirmar(
                        context,
                        'Excluir cofre?',
                        c.saldo > 0
                            ? 'Ainda tem ${moeda(c.saldo)} nesse cofre. Excluir mesmo assim?'
                            : 'Apaga o cofre e o histórico.');
                    if (ok) {
                      await dados.excluirCofre(c);
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'renomear', child: Text('Renomear')),
                  PopupMenuItem(value: 'excluir', child: Text('Excluir cofre')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              ResumoCard(titulo: 'Guardado', valor: c.saldo, cor: Cores.amarelo),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: MiniCard('Total guardado', c.totalPositivo, Cores.amarelo)),
                    const SizedBox(width: 10),
                    Expanded(child: MiniCard('Já devolvido', c.totalNegativo, Cores.laranja)),
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
                        texto: 'Guardar',
                        icone: Icons.add_rounded,
                        cor: Cores.amarelo,
                        aoTocar: () => _mover(context, c, true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BotaoAcao(
                        texto: 'Retirar',
                        icone: Icons.remove_rounded,
                        cor: Cores.laranja,
                        aoTocar: c.saldo <= 0 ? null : () => _mover(context, c, false),
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
                  titulo: m.positivo ? 'Guardado' : 'Retirado',
                  subtitulo: [dataBr(m.data), if (m.descricao.isNotEmpty) m.descricao]
                      .join(' · '),
                  valor: m.valor,
                  sinal: m.positivo ? '+' : '−',
                  data: m.data,
                  icone: m.positivo ? Icons.lock_rounded : Icons.lock_open_rounded,
                  cor: m.positivo ? Cores.amarelo : Cores.laranja,
                  aoTocar: () => _editar(context, c, m),
                )),
            ],
          ),
        );
      },
    );
  }
}
