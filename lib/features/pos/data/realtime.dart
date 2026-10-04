import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';

/// One message from the Go realtime hub: `{type, room, at, data}`.
class RealtimeEvent {
  const RealtimeEvent({required this.type, required this.data});

  final String type;
  final Map<String, dynamic> data;

  static RealtimeEvent? tryParse(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      return RealtimeEvent(
        type: json['type'] as String? ?? '',
        data: json['data'] as Map<String, dynamic>? ?? const {},
      );
    } catch (_) {
      return null;
    }
  }
}

/// Keeps a WebSocket open while someone listens; reconnects with backoff.
/// Fails soft: a dead socket only means no push, polling still works.
final realtimeEventsProvider = StreamProvider<RealtimeEvent>((ref) {
  final controller = StreamController<RealtimeEvent>.broadcast();
  final tokens = ref.watch(tokenStorageProvider);
  final user = ref.watch(authControllerProvider).value;
  var closed = false;
  WebSocketChannel? channel;

  Future<void> loop() async {
    var delay = const Duration(seconds: 2);
    while (!closed && user != null) {
      final token = await tokens.read();
      if (token == null || token.isEmpty) return;
      try {
        final uri = Uri.parse('${AppConfig.wsUrl}?token=$token');
        final ch = WebSocketChannel.connect(uri);
        channel = ch;
        await ch.ready;
        delay = const Duration(seconds: 2);
        await for (final msg in ch.stream) {
          final ev = RealtimeEvent.tryParse(msg);
          if (ev != null && !controller.isClosed) controller.add(ev);
        }
      } catch (_) {
        // swallow; retry below
      }
      if (closed) return;
      await Future<void>.delayed(delay);
      if (delay < const Duration(seconds: 30)) delay *= 2;
    }
  }

  loop();
  ref.onDispose(() {
    closed = true;
    channel?.sink.close();
    controller.close();
  });
  return controller.stream;
});
