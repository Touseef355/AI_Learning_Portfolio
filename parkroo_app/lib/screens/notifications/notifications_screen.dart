import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../api_service.dart';
import '../../utils/error_utils.dart';
import '../../widgets/common/pk_skeleton.dart';
import '../../widgets/common/micro_animations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    // Auto mark-read when screen opens
    ApiService.markAllNotificationsRead();
  }

  Future<void> _loadNotifications() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = data;
        _isLoading = false;
      });
    } catch (e, st) {
      ErrorUtils.logError('NotificationsScreen._loadNotifications', e, st);
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : ErrorUtils.friendlyMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead();
    } catch (e, st) {
      ErrorUtils.logError('NotificationsScreen._markAllRead', e, st);
    }
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
return Scaffold(
      backgroundColor: AppColors.of(context).bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.of(context).bgElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.of(context).border),
                      ),
                      child: Icon(Icons.arrow_back_ios_rounded,
                          size: 16, color: AppColors.of(context).textHint),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('Notifications',
                        style: TextStyle(fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.of(context).textPrimary)),
                  ),
                  if (_notifications.isNotEmpty)
                    TextButton(
                      onPressed: _markAllRead,
                      child: const Text('Mark all read',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.primary)),
                    ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? PkSkeletonList(
                      count: 7,
                      spacing: 0,
                      padding: EdgeInsets.zero,
                      itemBuilder: () => const PkSkeletonNotification(),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off_rounded,
                                  size: 48, color: AppColors.of(context).textHint),
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: TextStyle(
                                      color: AppColors.of(context).textHint,
                                      fontSize: 13)),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: _loadNotifications,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _notifications.isEmpty
                          ? const _NotifEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadNotifications,
                              color: AppColors.primary,
                              child: ListView.separated(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                itemCount: _notifications.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) => SpringSlideIn(
                                    delay: Duration(milliseconds: 40 * i),
                                    child: _NotifTile(notif: _notifications[i]),
                                  ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notification Tile ────────────────────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  final dynamic notif;
  const _NotifTile({required this.notif});

  // Map notification type to emoji + color
  static const _typeMap = {
    'booking_confirmed' : ('✅', 0xFF1A6FE8),
    'booking_cancelled' : ('❌', 0xFFEF4444),
    'booking_extended'  : ('📅', 0xFF1A6FE8),
    'overstay_alert'    : ('⚠️', 0xFFF59E0B),
    'payment_success'   : ('💳', 0xFF00C896),
    'refund'            : ('↩️', 0xFF8B5CF6),
    'wallet_topup'      : ('💰', 0xFF00C896),
  };

  @override
  Widget build(BuildContext context) {
final type    = notif['notification_type']?.toString() ?? '';
    final title   = notif['title']?.toString()   ?? 'Notification';
    final message = notif['message']?.toString()  ?? '';
    final isUnread = notif['is_read'] == false;
    final createdAt = notif['created_at']?.toString() ?? '';

    final (emoji, colorHex) = _typeMap[type] ?? ('🔔', 0xFF1A6FE8);
    final color = Color(colorHex);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnread
            ? AppColors.primary.withOpacity(0.05)
            : AppColors.of(context).bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnread
              ? AppColors.primary.withOpacity(0.2)
              : AppColors.of(context).border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(emoji,
                    style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isUnread
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: AppColors.of(context).textPrimary,
                        )),
                  ),
                  if (isUnread)
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ]),
                const SizedBox(height: 3),
                Text(message,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.of(context).textHint,
                        height: 1.4)),
                if (createdAt.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                        fontSize: 10, color: AppColors.of(context).textHint),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24)   return '${diff.inHours} hr ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}
// ── Notifications Empty State ─────────────────────────────────────────────────
class _NotifEmptyState extends StatefulWidget {
  const _NotifEmptyState();

  @override
  State<_NotifEmptyState> createState() => _NotifEmptyStateState();
}

class _NotifEmptyStateState extends State<_NotifEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _iconScale;
  late final Animation<double> _bellBounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic)));
    _iconScale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.1, 0.8, curve: Curves.easeOutBack)));
    _bellBounce = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _iconScale,
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withOpacity(0.12),
                              AppColors.primary.withOpacity(0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.16)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.notifications_none_rounded,
                          size: 46,
                          color: AppColors.primary.withOpacity(0.65),
                        ),
                      ),
                      // Badge dot
                      FadeTransition(
                        opacity: _bellBounce,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.of(context).bgBase,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppColors.of(context).border,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'All caught up!',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.of(context).textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "You're up to date.\nWe'll alert you on bookings & activity.",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.of(context).textSecondary,
                    height: 1.55,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}