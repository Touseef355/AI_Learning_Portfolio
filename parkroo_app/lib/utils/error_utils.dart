import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_constants.dart';
import '../theme/app_text_styles.dart';

/// Broad category of a failure — drives both the message shown to the user
/// and whether a "Retry" action makes sense.
enum AppErrorType {
  network,
  timeout,
  server,
  rateLimited,
  forbidden,
  notFound,
  validation,
  unknown,
}

/// A classified, user-safe error: a friendly [message] plus enough context
/// (type, whether it's worth retrying) to drive the UI.
class AppError {
  final AppErrorType type;
  final String message;
  final bool retryable;

  const AppError(this.type, this.message, {this.retryable = false});

  @override
  String toString() => message;
}

/// Central place for turning exceptions / HTTP responses into user-friendly
/// text, and for showing that text consistently across the app.
///
/// Nothing in here talks to the network — it only classifies errors that
/// already happened and renders them.
class ErrorUtils {
  ErrorUtils._();

  // Known backend messages we want to rephrase in friendlier terms. Matched
  // case-insensitively as a substring, so small backend wording changes
  // (e.g. "OTP Expired" vs "OTP expired") still match.
  static const Map<String, String> _messageOverrides = {
    'invalid otp': 'Wrong OTP. Please check and try again.',
    'invalid or expired token': 'Wrong OTP. Please check and try again.',
    'otp expired': 'This OTP has expired. Please request a new one.',
    'invalid email or password': 'Invalid email or password. Please try again.',
    'incorrect password': 'Incorrect password. Please try again.',
    'incorrect current password': 'Your current password is incorrect.',
    'passwords do not match': 'Passwords do not match. Please check and try again.',
  };

  static String applyKnownOverride(String raw) {
    final lower = raw.toLowerCase().trim();
    for (final entry in _messageOverrides.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return raw;
  }

  // ── Classifying exceptions (thrown before any HTTP response arrived) ────

  static AppError fromException(Object error) {
    if (error is SocketException) {
      return const AppError(
        AppErrorType.network,
        'No internet connection. Please check your network.',
        retryable: true,
      );
    }
    if (error is TimeoutException) {
      return const AppError(
        AppErrorType.timeout,
        'Server is taking too long. Please try again.',
        retryable: true,
      );
    }
    if (error is HttpException) {
      return const AppError(
        AppErrorType.network,
        'No internet connection. Please check your network.',
        retryable: true,
      );
    }
    if (error is FormatException) {
      return const AppError(
        AppErrorType.server,
        'Server error. Please try again later.',
        retryable: true,
      );
    }
    return const AppError(
      AppErrorType.unknown,
      'Something went wrong. Please try again.',
      retryable: true,
    );
  }

  /// Convenience for spots that only need the message string (matches the
  /// shape of the old `e.toString()` call sites, minus the raw text).
  static String friendlyMessage(Object error) => fromException(error).message;

  // ── Classifying HTTP responses ───────────────────────────────────────────

  /// [body] is the decoded JSON body, if any and if it decoded to a Map.
  static AppError fromStatusCode(int statusCode, {Map<String, dynamic>? body}) {
    final serverMessage = extractMessage(body);

    if (statusCode == 403) {
      return AppError(
        AppErrorType.forbidden,
        serverMessage != null
            ? applyKnownOverride(serverMessage)
            : "You don't have permission to do this.",
      );
    }
    if (statusCode == 404) {
      return const AppError(
        AppErrorType.notFound,
        'Service not found. Please try again later.',
      );
    }
    if (statusCode == 429) {
      return const AppError(
        AppErrorType.rateLimited,
        'Too many attempts. Please wait a moment.',
        retryable: true,
      );
    }
    if (statusCode >= 500) {
      return const AppError(
        AppErrorType.server,
        'Server error. Please try again later.',
        retryable: true,
      );
    }
    if (statusCode >= 400) {
      // 400/401/409 etc. — the backend usually already sends a specific,
      // useful message (wrong password, wrong OTP, validation errors).
      // Prefer that, just rephrased where we have a nicer version.
      if (serverMessage != null && serverMessage.trim().isNotEmpty) {
        return AppError(AppErrorType.validation, applyKnownOverride(serverMessage));
      }
      return const AppError(
        AppErrorType.validation,
        "That didn't work. Please check your details and try again.",
      );
    }
    return const AppError(
      AppErrorType.unknown,
      'Something went wrong. Please try again.',
      retryable: true,
    );
  }

  /// Pulls the best human-readable message out of a decoded JSON body.
  /// Handles Django/DRF's usual shapes: {"error": "..."}, {"detail": "..."},
  /// {"message": "..."}, and field-level validation errors like
  /// {"email": ["This field is required."]}.
  static String? extractMessage(Map<String, dynamic>? body) {
    if (body == null) return null;
    for (final key in ['error', 'detail', 'message']) {
      final v = body[key];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    for (final entry in body.entries) {
      final v = entry.value;
      if (v is List && v.isNotEmpty && v.first is String) {
        return v.first as String;
      }
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  /// Given a `Map<String, dynamic>` result from ApiService (which already
  /// guarantees a friendly `error` when something went wrong), pull out the
  /// message to display. Falls back to [fallback] if nothing usable is found.
  static String messageFrom(
    Map<String, dynamic>? result, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    final msg = extractMessage(result);
    if (msg == null || msg.trim().isEmpty) return fallback;
    return applyKnownOverride(msg);
  }

  /// Whether ApiService flagged this failed result as worth retrying
  /// (network/timeout/server/rate-limit — not a validation failure like a
  /// wrong password, where retrying the same input won't help).
  static bool isRetryable(Map<String, dynamic>? result) {
    return result?['_retryable'] == true;
  }

  // ── Debug logging ────────────────────────────────────────────────────────

  /// Centralized logging so failures are visible during development without
  /// ever reaching the user as raw text. Swap the implementation here if a
  /// real logging package is added later — call sites don't need to change.
  static void logError(String context, Object error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR][$context] $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  // ── UI: snackbar / dialog ────────────────────────────────────────────────

  /// The app's standard error snackbar — matches the Row(icon + text) style
  /// already used across most screens (settings, book_slot, etc.), now
  /// applied consistently everywhere, with an optional Retry action for
  /// errors worth retrying (network/timeout/server/rate-limit).
  static void showErrorSnack(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.white),
          ),
        ),
      ]),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(AppConstants.sp16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      duration: Duration(seconds: onRetry != null ? 6 : 4),
      action: onRetry == null
          ? null
          : SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: onRetry,
            ),
    ));
  }

  /// Shows [error]'s message via [showErrorSnack], wiring up a Retry action
  /// automatically when the error is retryable.
  static void showAppErrorSnack(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) {
    showErrorSnack(context, error.message, onRetry: error.retryable ? onRetry : null);
  }

  /// For failures blocking enough to warrant a modal dialog instead of a
  /// snackbar (used sparingly — e.g. account deletion, session-ending errors).
  static Future<void> showErrorDialog(
    BuildContext context,
    String message, {
    String title = 'Something went wrong',
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Thrown by ApiService's list-returning methods (getParkingSites, getSlots,
/// getVehicles, getBookings, getNotifications) when the request fails, so
/// screens can tell "failed" apart from "genuinely empty" and show a retry
/// option instead of silently rendering an empty state.
class ApiException implements Exception {
  final AppError error;
  const ApiException(this.error);

  String get message => error.message;

  @override
  String toString() => message;
}