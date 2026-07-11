import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/user_model.dart';
import 'utils/error_utils.dart';
typedef SessionExpiredCallback = void Function();

class ApiService {
  static const String baseUrl = 'https://recovery-isotope-struggle.ngrok-free.dev';

  // Applied to every network call so a hung connection surfaces as
  // "Server is taking too long" instead of spinning forever.
  static const Duration _timeout = Duration(seconds: 15);

  static const _keyAccess     = 'access_token';
  static const _keyRefresh    = 'refresh_token';
  static const _keyRole       = 'user_role';
  static const _keyName       = 'user_name';
  static const _keyEmail      = 'user_email';
  static const _keyPhone      = 'user_phone';
  static const _keyUserId     = 'user_id';
  static const _keyRemember   = 'remember_me';
  static const _keySavedEmail = 'saved_email';

  static SessionExpiredCallback? onSessionExpired;

  static UserModel? _cachedUser;
  static UserModel? get currentUser => _cachedUser;

  static Future<void> _updateCachedUser() async {
    final profile = await getProfile();
    if (profile['id'] != null && !profile.containsKey('error')) {
      _cachedUser = UserModel.fromJson(profile);
    }
  }

  // ── Response / error helpers ──────────────────────────────────────────
  //
  // Every method below funnels its HTTP response through _resultFor (for a
  // single JSON object) or _listFrom (for a JSON array), and every catch
  // block through _exceptionResult / logged + rethrown ApiException. That
  // means callers can always trust: a Map result's `error` key, when
  // present, is already a friendly, user-safe message — never raw
  // exception text — and list-returning calls throw ApiException (instead
  // of silently returning []) so screens can tell "failed" apart from
  // "genuinely empty" and offer a retry.

  static Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.body.isEmpty) return {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  static Map<String, dynamic> _resultFor(http.Response response) {
    final body = _decodeMap(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final appError = ErrorUtils.fromStatusCode(response.statusCode, body: body);
    return {...body, 'error': appError.message, '_retryable': appError.retryable};
  }

  static List<dynamic> _listFrom(http.Response response, String context) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return [];
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        return [];
      } catch (e, st) {
        ErrorUtils.logError(context, e, st);
        throw ApiException(ErrorUtils.fromException(e));
      }
    }
    final body = _decodeMap(response);
    final appError = ErrorUtils.fromStatusCode(response.statusCode, body: body);
    ErrorUtils.logError(context, 'HTTP ${response.statusCode}: ${appError.message}');
    throw ApiException(appError);
  }

  static Map<String, dynamic> _exceptionResult(String context, Object e, [StackTrace? st]) {
    ErrorUtils.logError(context, e, st);
    final appError = ErrorUtils.fromException(e);
    return {'error': appError.message, '_retryable': appError.retryable};
  }

  // ── Session Management ────────────────────────────────────

  static Future<void> saveSession(Map<String, dynamic> data) async {
    final prefs  = await SharedPreferences.getInstance();
    final tokens = data['tokens'] as Map<String, dynamic>?;
    if (tokens != null) {
      await prefs.setString(_keyAccess,  tokens['access']  ?? '');
      await prefs.setString(_keyRefresh, tokens['refresh'] ?? '');
    }
    if (data['role']         != null) await prefs.setString(_keyRole,   data['role']);
    if (data['name']         != null) await prefs.setString(_keyName,   data['name']);
    if (data['email']        != null) await prefs.setString(_keyEmail,  data['email']);
    if (data['phone_number'] != null) await prefs.setString(_keyPhone,  data['phone_number']);
    if (data['id']           != null) await prefs.setString(_keyUserId, data['id'].toString());
    await _updateCachedUser();
  }

  static Future<String> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccess) ?? '';
  }

  static Future<String> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefresh) ?? '';
  }

  static Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole) ?? 'user';
  }

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName) ?? '';
  }

  static Future<String> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail) ?? '';
  }

  static Future<String> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone) ?? '';
  }

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId) ?? '';
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyUserId);
    _cachedUser = null;
  }

  // ── Remember Me ───────────────────────────────────────────

  static Future<void> saveRememberMe(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRemember,     true);
    await prefs.setString(_keySavedEmail, email);
  }

  static Future<void> clearRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRemember);
    await prefs.remove(_keySavedEmail);
  }

  static Future<Map<String, dynamic>> getRememberMeData() async {
    final prefs      = await SharedPreferences.getInstance();
    final remember   = prefs.getBool(_keyRemember) ?? false;
    final savedEmail = prefs.getString(_keySavedEmail) ?? '';
    return {'remember': remember, 'email': savedEmail};
  }

  // ── Token Refresh ─────────────────────────────────────────

  static Future<String?> _refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken.isEmpty) {
        onSessionExpired?.call();
        return null;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/token/refresh/'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'refresh': refreshToken}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data   = _decodeMap(response);
        final access = data['access'] as String?;
        if (access != null && access.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyAccess, access);
          final newRefresh = data['refresh'] as String?;
          if (newRefresh != null && newRefresh.isNotEmpty) {
            await prefs.setString(_keyRefresh, newRefresh);
          }
          return access;
        }
      }
      await clearSession();
      onSessionExpired?.call();
      return null;
    } catch (e, st) {
      ErrorUtils.logError('ApiService._refreshAccessToken', e, st);
      await clearSession();
      onSessionExpired?.call();
      return null;
    }
  }

  // ── Auth Headers ──────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type':               'application/json',
      'Authorization':              'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
    };
  }

  static Map<String, String> get _publicHeaders => {
    'Content-Type':               'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  // ── Request Wrappers with Auto-Refresh ───────────────────

  static Future<http.Response> _getWithRefresh(String url) async {
    var headers  = await _authHeaders();
    var response = await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
    if (response.statusCode == 401) {
      final newToken = await _refreshAccessToken();
      if (newToken != null) {
        headers  = await _authHeaders();
        response = await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
      }
    }
    return response;
  }

  static Future<http.Response> _postWithRefresh(
    String url, {
    required Map<String, dynamic> body,
  }) async {
    var headers  = await _authHeaders();
    var response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(_timeout);
    if (response.statusCode == 401) {
      final newToken = await _refreshAccessToken();
      if (newToken != null) {
        headers  = await _authHeaders();
        response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(body),
        ).timeout(_timeout);
      }
    }
    return response;
  }

  static Future<http.Response> _patchWithRefresh(
    String url, {
    required Map<String, dynamic> body,
  }) async {
    var headers  = await _authHeaders();
    var response = await http.patch(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(_timeout);
    if (response.statusCode == 401) {
      final newToken = await _refreshAccessToken();
      if (newToken != null) {
        headers  = await _authHeaders();
        response = await http.patch(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(body),
        ).timeout(_timeout);
      }
    }
    return response;
  }

  static Future<http.Response> _putWithRefresh(
    String url, {
    required Map<String, dynamic> body,
  }) async {
    var headers  = await _authHeaders();
    var response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(_timeout);
    if (response.statusCode == 401) {
      final newToken = await _refreshAccessToken();
      if (newToken != null) {
        headers  = await _authHeaders();
        response = await http.put(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(body),
        ).timeout(_timeout);
      }
    }
    return response;
  }

  static Future<http.Response> _deleteWithRefresh(String url) async {
    var headers  = await _authHeaders();
    var response = await http.delete(Uri.parse(url), headers: headers).timeout(_timeout);
    if (response.statusCode == 401) {
      final newToken = await _refreshAccessToken();
      if (newToken != null) {
        headers  = await _authHeaders();
        response = await http.delete(Uri.parse(url), headers: headers).timeout(_timeout);
      }
    }
    return response;
  }

  // ── Auth ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login/'),
        headers: _publicHeaders,
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(_timeout);
      final data = _resultFor(response);
      if (response.statusCode == 200) {
        await saveSession(data);
        if (rememberMe) {
          await saveRememberMe(email);
        } else {
          await clearRememberMe();
        }
      }
      return data;
    } catch (e, st) {
      return _exceptionResult('ApiService.login', e, st);
    }
  }

  static Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    String role = 'user',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register/'),
        headers: _publicHeaders,
        body: jsonEncode({
          'full_name':        fullName,
          'email':            email,
          'phone_number':     phone,
          'password':         password,
          'confirm_password': confirmPassword,
          'role':             role,
        }),
      ).timeout(_timeout);
      final data = _resultFor(response);
      if (response.statusCode == 201) await saveSession(data);
      return data;
    } catch (e, st) {
      return _exceptionResult('ApiService.signup', e, st);
    }
  }

  static Future<void> logout() async {
    try {
      final refresh = await getRefreshToken();
      final headers = await _authHeaders();
      await http.post(
        Uri.parse('$baseUrl/api/auth/logout/'),
        headers: headers,
        body: jsonEncode({'refresh': refresh}),
      ).timeout(_timeout);
    } catch (e, st) {
      // Logout always clears the local session regardless — this is just
      // best-effort server-side token invalidation, log and move on.
      ErrorUtils.logError('ApiService.logout', e, st);
    } finally {
      await clearSession();
    }
  }

  // ── Profile ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _getWithRefresh('$baseUrl/api/auth/profile/');
      final data = _resultFor(response);
      if (response.statusCode == 200 && !data.containsKey('error')) {
        _cachedUser = UserModel.fromJson(data);
      }
      return data;
    } catch (e, st) {
      return _exceptionResult('ApiService.getProfile', e, st);
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? address,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (fullName    != null) body['full_name']    = fullName;
      if (phoneNumber != null) body['phone_number'] = phoneNumber;
      if (address     != null) body['address']      = address;

      final response = await _putWithRefresh(
        '$baseUrl/api/auth/profile/',
        body: body,
      );
      final data = _resultFor(response);
      if (response.statusCode == 200 && !data.containsKey('error')) {
        _cachedUser = UserModel.fromJson(data);
      }
      return data;
    } catch (e, st) {
      return _exceptionResult('ApiService.updateProfile', e, st);
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await _postWithRefresh(
        '$baseUrl/api/auth/password/change/',
        body: {
          'current_password': currentPassword,
          'new_password':     newPassword,
          'confirm_password': confirmPassword,
        },
      );
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.changePassword', e, st);
    }
  }

  static Future<Map<String, dynamic>> uploadProfilePhoto(File imageFile) async {
    try {
      Future<http.StreamedResponse> doRequest(String token) async {
        final request = http.MultipartRequest(
          'PATCH',
          Uri.parse('$baseUrl/api/auth/profile/'),
        );
        request.headers['Authorization']              = 'Bearer $token';
        request.headers['ngrok-skip-browser-warning'] = 'true';
        request.files.add(
          await http.MultipartFile.fromPath('profile_photo', imageFile.path),
        );
        return request.send().timeout(_timeout);
      }

      var token    = await getAccessToken();
      var streamed = await doRequest(token);

      if (streamed.statusCode == 401) {
        final newToken = await _refreshAccessToken();
        if (newToken != null) streamed = await doRequest(newToken);
      }

      final response = await http.Response.fromStream(streamed);
      final data = _resultFor(response);
      if (response.statusCode == 200 && !data.containsKey('error')) {
        _cachedUser = UserModel.fromJson(data);
      }
      return data;
    } catch (e, st) {
      return _exceptionResult('ApiService.uploadProfilePhoto', e, st);
    }
  }

  // ── OTP ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/otp/send/'),
        headers: _publicHeaders,
        body: jsonEncode({'phone_number': phoneNumber}),
      ).timeout(_timeout);
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.sendOtp', e, st);
    }
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/otp/verify/'),
        headers: _publicHeaders,
        body: jsonEncode({'phone_number': phoneNumber, 'otp_code': otpCode}),
      ).timeout(_timeout);
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.verifyOtp', e, st);
    }
  }

  // ── Password Reset ────────────────────────────────────────

  static Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/password/reset/'),
        headers: _publicHeaders,
        body: jsonEncode({'email': email}),
      ).timeout(_timeout);
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.requestPasswordReset', e, st);
    }
  }

  static Future<Map<String, dynamic>> verifyPasswordOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/password/verify/'),
        headers: _publicHeaders,
        body: jsonEncode({'email': email, 'otp_code': otpCode}),
      ).timeout(_timeout);
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.verifyPasswordOtp', e, st);
    }
  }

  static Future<Map<String, dynamic>> confirmPasswordReset({
    required String email,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/password/confirm/'),
        headers: _publicHeaders,
        body: jsonEncode({
          'email':            email,
          'new_password':     newPassword,
          'confirm_password': confirmPassword,
        }),
      ).timeout(_timeout);
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.confirmPasswordReset', e, st);
    }
  }

  // ── Parking Sites ─────────────────────────────────────────
  //
  // Throws ApiException on failure (network/timeout/4xx/5xx) instead of
  // silently returning [] — callers should wrap these in try/catch and show
  // ErrorUtils.showErrorSnack/showAppErrorSnack with a retry.

  static Future<List<dynamic>> getParkingSites() async {
    final response = await _getWithRefresh('$baseUrl/api/parking/sites/');
    return _listFrom(response, 'ApiService.getParkingSites');
  }

  static Future<List<dynamic>> getSlots(String siteId) async {
    final response = await _getWithRefresh(
      '$baseUrl/api/parking/sites/$siteId/slots/',
    );
    return _listFrom(response, 'ApiService.getSlots');
  }

  // ── Vehicles ──────────────────────────────────────────────

  static Future<List<dynamic>> getVehicles() async {
    final response = await _getWithRefresh('$baseUrl/api/parking/vehicles/');
    return _listFrom(response, 'ApiService.getVehicles');
  }

  static Future<Map<String, dynamic>> addVehicle({
    required String name,
    required String plateNumber,
    required String vehicleType,
    String? color,
  }) async {
    try {
      final response = await _postWithRefresh(
        '$baseUrl/api/parking/vehicles/',
        body: {
          'name':         name,
          'plate_number': plateNumber,
          'vehicle_type': vehicleType,
          'color':        color ?? '',
        },
      );
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.addVehicle', e, st);
    }
  }

  static Future<Map<String, dynamic>> updateVehicle({
    required String vehicleId,
    required String name,
    required String plateNumber,
    required String vehicleType,
    String? color,
  }) async {
    try {
      final response = await _putWithRefresh(
        '$baseUrl/api/parking/vehicles/$vehicleId/',
        body: {
          'name':         name,
          'plate_number': plateNumber,
          'vehicle_type': vehicleType,
          'color':        color ?? '',
        },
      );
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.updateVehicle', e, st);
    }
  }

  static Future<bool> deleteVehicle(String vehicleId) async {
    try {
      final response = await _deleteWithRefresh(
        '$baseUrl/api/parking/vehicles/$vehicleId/',
      );
      return response.statusCode == 204;
    } catch (e, st) {
      ErrorUtils.logError('ApiService.deleteVehicle', e, st);
      return false;
    }
  }

  // ── Bookings ──────────────────────────────────────────────

  static Future<List<dynamic>> getBookings() async {
    final response = await _getWithRefresh('$baseUrl/api/bookings/');
    return _listFrom(response, 'ApiService.getBookings');
  }

  static Future<Map<String, dynamic>> createBooking({
    required String parkingSlotId,
    required String vehicleId,
    required DateTime entryTime,
    required DateTime exitTime,
  }) async {
    try {
      final response = await _postWithRefresh(
        '$baseUrl/api/bookings/',
        body: {
          'parking_slot': parkingSlotId,
          'vehicle':      vehicleId,
          'entry_time':   entryTime.toUtc().toIso8601String(),
          'exit_time':    exitTime.toUtc().toIso8601String(),
        },
      );
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.createBooking', e, st);
    }
  }

  /// Preview the exact price BEFORE booking — same formula
  /// (parking.pricing.calculate_amount) the backend uses at booking-create
  /// time and at the gate, so this number and the eventual charge match.
  static Future<Map<String, dynamic>> estimateBookingPrice({
    required String slotId,
    required DateTime entryTime,
    required DateTime exitTime,
    String? vehicleId,
  }) async {
    try {
      final response = await _postWithRefresh(
        '$baseUrl/api/bookings/estimate/',
        body: {
          'slot_id':    slotId,
          'entry_time': entryTime.toUtc().toIso8601String(),
          'exit_time':  exitTime.toUtc().toIso8601String(),
          if (vehicleId != null) 'vehicle_id': vehicleId,
        },
      );
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.estimateBookingPrice', e, st);
    }
  }

  static Future<Map<String, dynamic>> extendBooking({
    required String bookingId,
    required DateTime extendedExitTime,
  }) async {
    try {
      final response = await _putWithRefresh(
        '$baseUrl/api/bookings/$bookingId/extend/',
        body: {
          'extended_exit_time': extendedExitTime.toUtc().toIso8601String(),
        },
      );
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.extendBooking', e, st);
    }
  }

  /// Preview what the refund policy gives back BEFORE cancelling — the
  /// backend uses the same computation for preview and actual refund.
  static Future<Map<String, dynamic>> getRefundPreview(String bookingId) async {
    try {
      final response = await _getWithRefresh(
        '$baseUrl/api/bookings/$bookingId/refund-preview/',
      );
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.getRefundPreview', e, st);
    }
  }

  static Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final response = await _deleteWithRefresh(
        '$baseUrl/api/bookings/$bookingId/',
      );
      if (response.statusCode == 200) {
        final body = _decodeMap(response);
        return {'status': 'cancelled', ...body};
      } else if (response.statusCode == 204) {
        return {'status': 'cancelled'};
      } else {
        return _resultFor(response);
      }
    } catch (e, st) {
      return _exceptionResult('ApiService.cancelBooking', e, st);
    }
  }

  // ── Wallet & Payments ─────────────────────────────────────

  static Future<Map<String, dynamic>> getAppConfig() async {
    try {
      final response = await _getWithRefresh('$baseUrl/api/config/');
      final data = _resultFor(response);
      // App config drives which payment gateway to use — degrade to mock
      // rather than surfacing an error for what's effectively a background
      // preference fetch.
      if (data.containsKey('error')) return {'payment_gateway': 'mock'};
      return data;
    } catch (e, st) {
      ErrorUtils.logError('ApiService.getAppConfig', e, st);
      return {'payment_gateway': 'mock'};
    }
  }

  static Future<Map<String, dynamic>> getWallet() async {
    try {
      final response = await _getWithRefresh('$baseUrl/api/payments/wallet/');
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.getWallet', e, st);
    }
  }

  static Future<Map<String, dynamic>> initiateTopUp({
    required double amount,
  }) async {
    try {
      final response = await _postWithRefresh(
        '$baseUrl/api/payments/wallet/topup/initiate/',
        body: {'amount': amount},
      );
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.initiateTopUp', e, st);
    }
  }

  static Future<Map<String, dynamic>> deductWallet({
    required String bookingId,
    required double amount,
  }) async {
    try {
      final response = await _postWithRefresh(
        '$baseUrl/api/payments/wallet/deduct/',
        body: {'booking_id': bookingId, 'amount': amount},
      );
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.deductWallet', e, st);
    }
  }

  static Future<Map<String, dynamic>> deleteAccount(String password) async {
    try {
      final headers  = await _authHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/auth/delete/'),
        headers: headers,
        body: jsonEncode({'password': password}),
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        await clearSession();
      }
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.deleteAccount', e, st);
    }
  }

  // ── Notifications ─────────────────────────────────────────

  static Future<List<dynamic>> getNotifications() async {
    final response = await _getWithRefresh('$baseUrl/api/notifications/');
    return _listFrom(response, 'ApiService.getNotifications');
  }

  static Future<void> markAllNotificationsRead() async {
    try {
      await _postWithRefresh(
        '$baseUrl/api/notifications/mark-all-read/',
        body: {},
      );
    } catch (e, st) {
      ErrorUtils.logError('ApiService.markAllNotificationsRead', e, st);
    }
  }

  // ── Parking Passes ────────────────────────────────────────

  static Future<Map<String, dynamic>> previewPass({
    required String slotId,
    required int durationWeeks,
    required String dailyStart, // "HH:MM"
    required String dailyEnd,
    String? startDate, // "YYYY-MM-DD", default today
  }) async {
    try {
      final response = await _postWithRefresh(
        '$baseUrl/api/bookings/passes/preview/',
        body: {
          'slot_id': slotId,
          'duration_weeks': durationWeeks,
          'daily_start': dailyStart,
          'daily_end': dailyEnd,
          if (startDate != null) 'start_date': startDate,
        },
      );
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.previewPass', e, st);
    }
  }

  static Future<Map<String, dynamic>> createPass({
    required String slotId,
    required String vehicleId,
    required int durationWeeks,
    required String dailyStart,
    required String dailyEnd,
    String? startDate,
  }) async {
    try {
      final response = await _postWithRefresh(
        '$baseUrl/api/bookings/passes/',
        body: {
          'slot_id': slotId,
          'vehicle_id': vehicleId,
          'duration_weeks': durationWeeks,
          'daily_start': dailyStart,
          'daily_end': dailyEnd,
          if (startDate != null) 'start_date': startDate,
        },
      );
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.createPass', e, st);
    }
  }

  static Future<List<dynamic>> getMyPasses() async {
    final response = await _getWithRefresh('$baseUrl/api/bookings/passes/');
    return _listFrom(response, 'ApiService.getMyPasses');
  }

  static Future<Map<String, dynamic>> cancelPass(String passId) async {
    try {
      final response =
          await _deleteWithRefresh('$baseUrl/api/bookings/passes/$passId/');
      return _resultFor(response);
    } catch (e, st) {
      return _exceptionResult('ApiService.cancelPass', e, st);
    }
  }
}