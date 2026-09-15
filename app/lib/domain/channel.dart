import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum Channel { wa, wechat }

Channel channelFrom(String s) => s == 'wechat' ? Channel.wechat : Channel.wa;

/// ⚠ SPIKE 0.2 RESULT — the WhatsApp URL is NOT portable.
///
/// On macOS, `https://wa.me/...` resolves to Safari, not WhatsApp: the desktop
/// app registers the `whatsapp://` scheme but ships no associated-domains
/// entitlement, so it never claims wa.me universal links. Verified against
/// LaunchServices, then confirmed by hand.
///
/// On iOS/Android, `wa.me` is the correct link and `whatsapp://` is not.
/// Both prior design docs specify wa.me throughout; that is right for the
/// phone client in Phase 7 and wrong for the Mac client being built now.
///
/// Windows follows the Mac: WhatsApp Desktop registers the same `whatsapp:`
/// protocol, and wa.me opens the browser. Not yet confirmed on a machine.
Uri whatsappUri(String number, String text) {
  final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
  final body = Uri.encodeComponent(text);
  return Platform.isMacOS || Platform.isWindows
      ? Uri.parse('whatsapp://send?phone=$digits&text=$body')
      : Uri.parse('https://wa.me/$digits?text=$body');
}

Future<bool> openWhatsApp(String number, String text) =>
    launchUrl(whatsappUri(number, text));

/// ⛔ No reliable deep link to a specific WeChat chat exists. `weixin://`
/// opens the app but cannot target a person. The fallback is copy-ID,
/// switch, search, paste — roughly 4x slower than the WhatsApp path, which
/// is why the occasion screen groups WeChat contacts together so the
/// context-switch happens once rather than twelve times.
Future<void> copyForWeChat(String wechatId, String greeting) async {
  await Clipboard.setData(ClipboardData(text: greeting));
}

Future<void> copyWeChatId(String wechatId) async {
  await Clipboard.setData(ClipboardData(text: wechatId));
}

Future<void> openWeChat() async {
  final uri = Uri.parse('weixin://');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}
