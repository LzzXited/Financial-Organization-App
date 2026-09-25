import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'formato.dart';
import 'modelos.dart';

/// Lembretes das assinaturas (todo mês, no dia do vencimento, às 9h).
class Notificacoes {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _pronto = false;

  static const _detalhes = NotificationDetails(
    android: AndroidNotificationDetails(
      'lembretes_assinaturas',
      'Lembretes de Assinaturas',
      channelDescription: 'Avisa no dia de pagar cada assinatura',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> iniciar() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      const android = AndroidInitializationSettings('ic_notificacao');
      await _plugin.initialize(const InitializationSettings(android: android));
      _pronto = true;
    } catch (e) {
      debugPrint('Notificações indisponíveis: $e');
    }
  }

  static Future<bool> pedirPermissao() async {
    if (!_pronto) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancelar(Assinatura a) async {
    if (!_pronto) return;
    try {
      await _plugin.cancel(a.notifId);
    } catch (_) {}
  }

  static Future<void> agendar(Assinatura a) async {
    if (!_pronto) return;
    await cancelar(a);
    if (!a.lembrete) return;
    try {
      final agora = tz.TZDateTime.now(tz.local);
      var ano = agora.year;
      var mes = agora.month;
      var alvo = _data(ano, mes, a.dia);
      if (!alvo.isAfter(agora)) {
        mes++;
        if (mes > 12) {
          mes = 1;
          ano++;
        }
        alvo = _data(ano, mes, a.dia);
      }
      await _plugin.zonedSchedule(
        a.notifId,
        'Hoje é dia de pagar: ${a.descricao}',
        'Valor: ${moeda(a.valor)}',
        alvo,
        _detalhes,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    } catch (e) {
      debugPrint('Erro ao agendar lembrete: $e');
    }
  }

  /// Dia limitado ao último dia do mês (ex.: dia 31 em setembro vira 30).
  static tz.TZDateTime _data(int ano, int mes, int dia) {
    final ultimo = DateTime(ano, mes + 1, 0).day;
    return tz.TZDateTime(tz.local, ano, mes, dia > ultimo ? ultimo : dia, 9);
  }

  static Future<void> testar() async {
    if (!_pronto) return;
    await pedirPermissao();
    await _plugin.show(
      999999,
      'Tudo certo!',
      'Os lembretes das assinaturas vão aparecer assim.',
      _detalhes,
    );
  }
}
