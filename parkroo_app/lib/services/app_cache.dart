import 'dart:async';
import 'package:flutter/widgets.dart';

/// ─────────────────────────────────────────────────────────────────────
/// AppCache — stale-while-revalidate data layer (TanStack Query ka
/// Flutter-sized bhai).
///
/// Pattern:
///   1. Screen khulte hi cached data INSTANTLY milta hai (koi spinner
///      nahi agar cache mein kuch hai)
///   2. Background mein fresh fetch hota hai; aate hi listeners notify
///      hote hain aur UI chupchaap update ho jati hai
///   3. Mutations ke baad invalidate() se related data foran taaza
///
/// Usage screens mein CachedScreenState ke through hota hai (neeche).
/// ─────────────────────────────────────────────────────────────────────
class AppCache {
  AppCache._();
  static final AppCache instance = AppCache._();

  final Map<String, dynamic> _data = {};
  final Map<String, DateTime> _fetchedAt = {};
  final Map<String, Future<dynamic>> _inflight = {};
  final Map<String, Set<VoidCallback>> _listeners = {};

  /// Cached value abhi, bina fetch ke. Null agar kabhi load nahi hua.
  T? peek<T>(String key) => _data[key] as T?;

  bool isFresh(String key, Duration ttl) {
    final t = _fetchedAt[key];
    return t != null && DateTime.now().difference(t) < ttl;
  }

  /// SWR fetch: fresh cache ho toh wohi return, warna fetch (in-flight
  /// dedupe ke saath — 3 screens ek saath maangein toh network call EK).
  Future<T> fetch<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration ttl = const Duration(seconds: 15),
    bool force = false,
  }) async {
    if (!force && isFresh(key, ttl) && _data.containsKey(key)) {
      return _data[key] as T;
    }
    if (_inflight.containsKey(key)) {
      return await _inflight[key] as T;
    }
    final future = fetcher();
    _inflight[key] = future;
    try {
      final result = await future;
      _data[key] = result;
      _fetchedAt[key] = DateTime.now();
      _notify(key);
      return result;
    } finally {
      _inflight.remove(key);
    }
  }

  /// Mutation ke baad: is prefix ki saari keys stale mark karo aur
  /// listeners ko refetch ka ishara do.
  /// e.g. booking cancel hui → invalidate('bookings'), invalidate('wallet')
  void invalidate(String prefix) {
    final keys = _fetchedAt.keys.where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) {
      _fetchedAt.remove(k); // data rakho (stale dikhta rahe), freshness hatao
      _notify(k);
    }
  }

  void addListener(String key, VoidCallback cb) =>
      (_listeners[key] ??= {}).add(cb);

  void removeListener(String key, VoidCallback cb) =>
      _listeners[key]?.remove(cb);

  void _notify(String key) {
    for (final cb in List.of(_listeners[key] ?? const <VoidCallback>{})) {
      cb();
    }
  }

  /// Logout pe sab saaf.
  void clear() {
    _data.clear();
    _fetchedAt.clear();
    _inflight.clear();
  }
}

/// Global route observer — MaterialApp ke navigatorObservers mein
/// register hota hai (main.dart), taake screens ko pata chale ke user
/// unpe WAPAS aaya hai (didPopNext) aur woh khud refresh kar lein.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// ─────────────────────────────────────────────────────────────────────
/// CachedScreenState — screens ke liye base State jo teeno refresh
/// triggers free mein deta hai:
///
///   1. SWR initial load  : cache hai toh instant render + silent refresh
///   2. Periodic silent   : har [refreshInterval] pe chupke se refetch
///   3. Return-to-screen  : back navigate karke wapas aao → refetch
///
/// Screen sirf 2 cheezein override karti hai:
///   cacheKey       — is screen ke data ki key (e.g. 'bookings:list')
///   fetchData()    — network call
///   onData(value)  — setState karke apna state bharo
///
/// Loading flag khud manage hota hai: [showInitialLoader] sirf tab true
/// jab cache bilkul khali ho.
/// ─────────────────────────────────────────────────────────────────────
abstract class CachedScreenState<W extends StatefulWidget, T>
    extends State<W> with RouteAware {
  String get cacheKey;
  Duration get ttl => const Duration(seconds: 15);
  Duration get refreshInterval => const Duration(seconds: 20);

  Future<T> fetchData();
  void onData(T value);
  void onFirstLoadError(Object e, StackTrace st) {}

  bool showInitialLoader = true;
  Timer? _timer;
  late final VoidCallback _cacheListener;

  @override
  void initState() {
    super.initState();

    _cacheListener = () {
      if (!mounted) return;
      // Invalidation ke baad key stale hoti hai — foran refetch karo
      // (realtime events yahi trigger karte hain). Fresh update ho toh
      // bas naya data state mein daalo.
      if (!AppCache.instance.isFresh(cacheKey, ttl)) {
        _load();
      } else {
        final v = AppCache.instance.peek<T>(cacheKey);
        if (v != null) onData(v);
      }
    };
    AppCache.instance.addListener(cacheKey, _cacheListener);

    // 1) Cache se instant render, agar hai
    final cached = AppCache.instance.peek<T>(cacheKey);
    if (cached != null) {
      showInitialLoader = false;
      // initState ke baad frame pe onData — build se pehle setState avoid
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onData(cached);
      });
    }

    // 2) Fresh fetch (cache stale ho ya na ho — pehli visit pe zaroor)
    _load(initial: true);

    // 3) Periodic silent refresh
    _timer = Timer.periodic(refreshInterval, (_) {
      if (mounted) _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  /// User is screen pe WAPAS aaya (kisi detail screen se pop hua) —
  /// data foran taaza karo, silently.
  @override
  void didPopNext() => _load();

  Future<void> _load({bool initial = false}) async {
    try {
      final value = await AppCache.instance
          .fetch<T>(cacheKey, fetchData, ttl: ttl, force: !initial);
      if (!mounted) return;
      if (showInitialLoader) setState(() => showInitialLoader = false);
      onData(value);
    } catch (e, st) {
      if (!mounted) return;
      if (showInitialLoader) {
        setState(() => showInitialLoader = false);
        onFirstLoadError(e, st);
      }
      // Silent refresh failures UI ko disturb nahi karte — purana data
      // dikhta rehta hai, agla tick retry karega.
    }
  }

  /// Pull-to-refresh ke liye — force fetch.
  Future<void> refreshNow() => _load();

  @override
  void dispose() {
    _timer?.cancel();
    AppCache.instance.removeListener(cacheKey, _cacheListener);
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }
}
