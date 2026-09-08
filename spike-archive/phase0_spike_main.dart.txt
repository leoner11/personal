// PHASE 0 SPIKE HARNESS — throwaway. Delete when Phase 1 starts.
// Answers: 0.1 notification persistence · 0.2 WhatsApp deep link · 0.3 shell viability
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

final plugin = FlutterLocalNotificationsPlugin();
final log = <String>[];
void p(String s) {
  // ignore: avoid_print
  print('[SPIKE] $s');
  log.add(s);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(900, 560),
      minimumSize: Size(900, 560),
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    ),
    () async {
      await windowManager.show();
    },
  );

  tzdata.initializeTimeZones();
  final info = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(info.identifier));
  p('0.3 timezone = ${info.identifier}  now=${tz.TZDateTime.now(tz.local)}');

  final ok = await plugin.initialize(
    settings: const InitializationSettings(
      macOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    ),
  );
  p('0.1 initialize() -> $ok  (UNRELIABLE: returns before the prompt is answered)');
  final mac = plugin.resolvePlatformSpecificImplementation<
      MacOSFlutterLocalNotificationsPlugin>();
  final perms = await mac?.checkPermissions();
  p('0.1 checkPermissions -> alert=${perms?.isAlertEnabled} '
      'sound=${perms?.isSoundEnabled} badge=${perms?.isBadgeEnabled}');

  // THE CRITICAL READING: what survived the last quit / reboot / rebuild?
  final pending = await plugin.pendingNotificationRequests();
  p('0.1 PENDING ON LAUNCH = ${pending.length}');
  for (final n in pending) {
    p('0.1   id=${n.id} title=${n.title} body=${n.body}');
  }

  if (pending.isEmpty) {
    p('0.1 none pending -> scheduling the +3d canary now');
    await schedule(2, 'SPIKE +3 days', const Duration(days: 3));
  } else {
    p('0.1 CANARY SURVIVED — did not reschedule');
  }
  final after = await plugin.pendingNotificationRequests();
  p('0.1 PENDING AFTER = ${after.length}');

  runApp(SpikeApp(pendingOnLaunch: after.length));
}

Future<void> schedule(int id, String title, Duration ahead) async {
  final when = tz.TZDateTime.now(tz.local).add(ahead);
  await plugin.zonedSchedule(
    id: id,
    title: title,
    body: 'scheduled ${DateTime.now()} for $when',
    scheduledDate: when,
    notificationDetails: const NotificationDetails(
      macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );
  p('0.1 scheduled id=$id at $when');
}

class SpikeApp extends StatefulWidget {
  const SpikeApp({super.key, required this.pendingOnLaunch});
  final int pendingOnLaunch;
  @override
  State<SpikeApp> createState() => _SpikeAppState();
}

class _SpikeAppState extends State<SpikeApp> {
  final _phone = TextEditingController();
  String _out = '';
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _pending = widget.pendingOnLaunch;
  }

  Future<void> _refresh() async {
    final n = await plugin.pendingNotificationRequests();
    setState(() {
      _pending = n.length;
      _out = n.map((e) => 'id=${e.id} ${e.title}').join('\n');
    });
  }

  Future<void> _try(String url) async {
    final uri = Uri.parse(url);
    final can = await canLaunchUrl(uri);
    var launched = false;
    try {
      launched = await launchUrl(uri);
    } catch (e) {
      setState(() => _out = '$url\nthrew: $e');
      return;
    }
    setState(() => _out = '$url\ncanLaunch=$can  launched=$launched');
    p('0.2 $url canLaunch=$can launched=$launched');
  }

  @override
  Widget build(BuildContext context) {
    // 0.3 — null fontFamily must resolve to San Francisco, not Roboto.
    final resolved = DefaultTextStyle.of(context).style.fontFamily ?? 'null (system)';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        visualDensity: VisualDensity.compact,
        fontFamily: null,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFF6F5F1),
        body: DragToMoveArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 34, 20, 20),
            child: DefaultTextStyle(
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1B1F1D),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PHASE 0 SPIKES',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('0.3  font=$resolved · dart=${Platform.version.split(" ").first} · '
                      '13pt body · tabular 0123456789 / 1111111111',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF5A625D))),
                  const Divider(height: 20),

                  Text('0.1  NOTIFICATIONS — pending right now: $_pending',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Text('Schedule +3d, then: quit → reopen → reboot → rebuild. '
                      'Pending must stay 1 at every step.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF5A625D))),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(
                        onPressed: () async {
                          await schedule(1, 'SPIKE +30s', const Duration(seconds: 30));
                          await _refresh();
                        },
                        child: const Text('schedule +30s')),
                    OutlinedButton(
                        onPressed: () async {
                          await schedule(2, 'SPIKE +3 days', const Duration(days: 3));
                          await _refresh();
                        },
                        child: const Text('schedule +3 days')),
                    OutlinedButton(onPressed: _refresh, child: const Text('refresh pending')),
                    OutlinedButton(
                        onPressed: () async {
                          await plugin.cancelAll();
                          await _refresh();
                        },
                        child: const Text('cancel all')),
                  ]),

                  const Divider(height: 20),
                  const Text('0.2  WHATSAPP DEEP LINK',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Text('Enter a REAL number in full international form, no + or spaces '
                      '(e.g. 6281234567890). Nothing sends — it only opens the chat.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF5A625D))),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 280,
                    height: 28,
                    child: TextField(
                      controller: _phone,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(),
                        hintText: 'your own number',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(
                        onPressed: () => _try(
                            'whatsapp://send?phone=${_phone.text}&text=${Uri.encodeComponent("中秋节快乐 — spike")}'),
                        child: const Text('whatsapp:// scheme')),
                    OutlinedButton(
                        onPressed: () => _try(
                            'https://wa.me/${_phone.text}?text=${Uri.encodeComponent("中秋节快乐 — spike")}'),
                        child: const Text('https://wa.me')),
                  ]),

                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE0DFD9)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(_out.isEmpty ? '—' : _out,
                            style: const TextStyle(fontSize: 11, fontFamily: 'Menlo')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
