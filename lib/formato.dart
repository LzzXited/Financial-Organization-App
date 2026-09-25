import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat('#,##0.00', 'pt_BR');
final _data = DateFormat('dd/MM/yyyy');

/// 946040 -> "R$ 9.460,40"
String moeda(int centavos) =>
    _moeda.format(centavos / 100).replaceAll(' ', ' ');

/// 946040 -> "9.460,40"
String numero(int centavos) => _numero.format(centavos / 100);

String dataBr(DateTime d) => _data.format(d);

const _meses = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho',
  'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
];

String nomeMes(DateTime d) => _meses[d.month - 1];

String mesAno(DateTime d) => '${nomeMes(d)} de ${d.year}';

/// "Hoje", "Ontem" ou a data.
String dataAmigavel(DateTime d) {
  final hoje = DateTime.now();
  final h = DateTime(hoje.year, hoje.month, hoje.day);
  final x = DateTime(d.year, d.month, d.day);
  final dif = h.difference(x).inDays;
  if (dif == 0) return 'Hoje';
  if (dif == 1) return 'Ontem';
  if (dif == -1) return 'Amanhã';
  return dataBr(d);
}

/// Converte o texto do campo de valor ("1.234,56") em centavos.
int centavosDoTexto(String t) {
  final digitos = t.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitos.isEmpty) return 0;
  return int.tryParse(digitos) ?? 0;
}

/// Campo de valor tipo "caixa eletrônico": digita 1, 2, 3 -> 0,01 / 0,12 / 1,23.
class FormatoCentavos extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digitos = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.length > 11) digitos = digitos.substring(0, 11);
    final c = digitos.isEmpty ? 0 : int.parse(digitos);
    final txt = numero(c);
    return TextEditingValue(
      text: txt,
      selection: TextSelection.collapsed(offset: txt.length),
    );
  }
}
