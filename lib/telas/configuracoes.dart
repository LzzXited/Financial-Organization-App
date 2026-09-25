import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../dados.dart';
import '../notificacoes.dart';
import '../tema.dart';
import '../widgets.dart';

class ConfiguracoesPage extends StatelessWidget {
  const ConfiguracoesPage({super.key});

  Future<void> _exportar(BuildContext context) async {
    try {
      final agora = DateTime.now();
      final nomeArq =
          'financas_backup_${agora.year}-${agora.month.toString().padLeft(2, '0')}-${agora.day.toString().padLeft(2, '0')}.json';
      final dir = await getTemporaryDirectory();
      final arq = File('${dir.path}/$nomeArq');
      await arq.writeAsString(
          const JsonEncoder.withIndent('  ').convert(dados.paraMapa()));
      await Share.shareXFiles(
        [XFile(arq.path, mimeType: 'application/json')],
        subject: 'Backup Minhas Finanças',
        text: 'Backup do app Minhas Finanças',
      );
    } catch (e) {
      if (context.mounted) aviso(context, 'Não foi possível exportar: $e');
    }
  }

  Future<void> _importar(BuildContext context) async {
    final ok = await confirmar(
      context,
      'Importar backup?',
      'Todos os dados atuais do app serão substituídos pelos do arquivo.',
      sim: 'Escolher arquivo',
      cor: Cores.roxo,
    );
    if (!ok) return;
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (r == null || r.files.isEmpty) return;
      final f = r.files.single;
      String texto;
      if (f.bytes != null) {
        texto = utf8.decode(f.bytes!);
      } else if (f.path != null) {
        texto = await File(f.path!).readAsString();
      } else {
        throw const FormatException('Não consegui ler o arquivo.');
      }
      await dados.importar(texto);
      if (context.mounted) aviso(context, 'Backup importado com sucesso!');
    } on FormatException catch (e) {
      if (context.mounted) aviso(context, e.message);
    } catch (e) {
      if (context.mounted) aviso(context, 'Arquivo inválido: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dados,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Configurações')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _Secao('Você', [
              ListTile(
                leading: const Icon(Icons.person_rounded, color: Cores.roxo),
                title: const Text('Seu nome'),
                subtitle: Text(dados.nome.isEmpty ? 'Toque para definir' : dados.nome),
                onTap: () async {
                  final n = await pedirTexto(context, 'Como quer ser chamado?',
                      inicial: dados.nome);
                  if (n != null) await dados.setNome(n);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off_rounded, color: Cores.roxo),
                title: const Text('Esconder valores'),
                subtitle: const Text('Útil para abrir o app perto de outras pessoas'),
                value: dados.ocultarValores,
                onChanged: (v) => dados.setOcultar(v),
              ),
            ]),
            _Secao('Backup', [
              ListTile(
                leading: const Icon(Icons.upload_rounded, color: Cores.verde),
                title: const Text('Exportar backup'),
                subtitle: const Text(
                    'Gera um arquivo com todos os seus dados. Mande para o seu e-mail, Drive ou WhatsApp.'),
                onTap: () => _exportar(context),
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Cores.azul),
                title: const Text('Importar backup'),
                subtitle: const Text('Restaura os dados de um arquivo exportado antes'),
                onTap: () => _importar(context),
              ),
            ]),
            _Secao('Lembretes', [
              ListTile(
                leading: const Icon(Icons.notifications_active_rounded,
                    color: Cores.amarelo),
                title: const Text('Testar notificação'),
                subtitle: const Text('Pede a permissão e mostra um aviso de teste'),
                onTap: () async {
                  await Notificacoes.testar();
                  await dados.reagendarLembretes();
                },
              ),
            ]),
            _Secao('Como o saldo é calculado', const [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Text(
                  '• Livre = entradas recebidas − saídas pagas − empréstimos + pagamentos recebidos.\n'
                  '• Investido = soma dos rendimentos.\n'
                  '• Na rua = o que as pessoas ainda te devem.\n'
                  '• Saldo geral = Livre + Investido + Na rua − A pagar.\n\n'
                  'Emprestar dinheiro não muda o saldo geral: sai do Livre e entra no Na rua. '
                  'Quando a pessoa paga, volta para o Livre.\n\n'
                  'Cofres de terceiros não entram no saldo, porque o dinheiro não é seu.\n\n'
                  'Contas "a receber" não entram no saldo até você marcar como recebidas.',
                  style: TextStyle(color: Cores.texto2, height: 1.45),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final List<Widget> filhos;
  const _Secao(this.titulo, this.filhos);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(titulo.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Cores.texto3)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Cores.card,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: filhos),
          ),
        ),
      ],
    );
  }
}
