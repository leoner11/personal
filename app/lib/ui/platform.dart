import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Where the Mac and Windows desktop shells differ, kept in one place so no
/// screen branches on Platform itself.
bool get isMac => Platform.isMacOS;

/// ⚠ Space each pane leaves clear at the top. On the Mac the titlebar is
/// hidden but the traffic lights stay, drawn over our content, so everything
/// starts below them. Windows keeps its native titlebar — hiding it there
/// removes minimise, maximise and close outright — so there is nothing to
/// clear and 38px of dead space would just look broken.
double get titlebarInset => isMac ? 38 : 12;

/// ⌘ on the Mac, Ctrl on Windows. A Windows keyboard's meta key is the
/// Windows key, which the system claims for itself.
SingleActivator cmd(LogicalKeyboardKey key) =>
    SingleActivator(key, meta: isMac, control: !isMac);

/// The same modifier as written in hint text: "⌘N" or "Ctrl+N".
String cmdLabel(String key) => isMac ? '⌘$key' : 'Ctrl+$key';
