import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../api_service.dart';
import 'app_cache.dart';

/// ─────────────────────────────────────────────────────────────────────
/// RealtimeService — server ke change-events ko AppCache invalidation
/// se jorta hai. Server pe kuch badla (booking confirm, wallet credit,
/// notification) → yahan event aata hai → related cache keys stale ho
/// jati hain → jo screen khuli hai woh khud refetch kar leti hai.
///
/// Login ke baad `RealtimeService.instance.connect()` (dashboard
/// initState mein wired hai), logout pe `disconnect()`.
/// Reconnect exponential backoff se hota hai; disconnect ke doran
/// CachedScreenState ka periodic polling fallback ka kaam karta hai.
/// ─────────────────────────────────────────────────────────────────────
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  static String get _wsUrl {
    // ApiService.baseUrl (http/https) -> ws/wss
    final base = ApiService.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$base/ws/events/';
  }

  /// Server event -> kaunse cache prefixes stale hote hain.
  /// Notification types bhi map hote hain kyunki har user-facing change
  /// ke saath notification aati hai — ek event, sahi jagah refresh.
  static const _eventInvalidations = <String, List<String>>{
    'slots.changed': ['sites', 'slots'],
    'bookings.changed': ['bookings'],
    'payments.changed': ['wallet'],
  };
  static const _notificationTypeInvalidations = <String, List<String>>{
    'booking_confirmed': ['bookings', 'wallet', 'notifications'],
    'booking_cancelled': ['bookings', 'notifications'],
    'booking_extended': ['bookings', 'notifications'],
    'payment_success': ['wallet', 'bookings', 'notifications'],
    'refund': ['wallet', 'bookings', 'notifications'],
    'wallet_topup': ['wallet', 'notifications'],
    'overstay_alert': ['wallet', 'bookings', 'notifications'],
  };

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  int _retrySeconds = 1;
  bool _shouldRun = false;

  Future<void> connect() async {
    if (_shouldRun) return; // already running
    _shouldRun = true;
    await _open();
  }

  Future<void> disconnect() async {
    _shouldRun = false;
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> _open() async {
    if (!_shouldRun) return;
    final token = await ApiService.getAccessToken();
    if (token.isEmpty) {
      _scheduleReconnect();
      return;
    }
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _sub = _channel!.stream.listen(
        _onMessage,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
      // Same first-message auth handshake as gate consumers.
      _channel!.sink.add(jsonEncode({'token': token}));
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (msg['type'] == 'auth_success') {
      _retrySeconds = 1; // healthy — backoff reset
      return;
    }

    final event = msg['event']?.toString();
    if (event == null) return;

    final prefixes = <String>{
      ...?_eventInvalidations[event],
    };
    if (event == 'notification') {
      final nType =
          (msg['data']?['notification_type'] ?? '').toString();
      prefixes.addAll(
          _notificationTypeInvalidations[nType] ?? const ['notifications']);
    }
    for (final p in prefixes) {
      AppCache.instance.invalidate(p);
    }
  }

  void _scheduleReconnect() {
    if (!_shouldRun) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _retrySeconds), _open);
    _retrySeconds = min(_retrySeconds * 2, 30);
  }
}
