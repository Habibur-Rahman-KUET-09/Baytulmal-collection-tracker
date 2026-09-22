import 'package:shared_preferences/shared_preferences.dart';

/// Implements account lockout after failed login attempts (OWASP A07:2021 –
/// Identification and Authentication Failures). Locks accounts for 15 minutes
/// after 3 failed attempts.
class RateLimiterService {
  static const int _maxFailedAttempts = 3;
  static const int _lockoutDurationMinutes = 15;

  RateLimiterService._();
  static final RateLimiterService instance = RateLimiterService._();

  String _lockoutKey(String email) => 'lockout_$email';
  String _attemptsKey(String email) => 'attempts_$email';

  /// Check if an email is currently locked out.
  Future<bool> isLockedOut(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutTime = prefs.getInt(_lockoutKey(email));
    if (lockoutTime == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now > lockoutTime) {
      // Lockout expired, clear it
      await prefs.remove(_lockoutKey(email));
      await prefs.remove(_attemptsKey(email));
      return false;
    }
    return true;
  }

  /// Get remaining lockout time in minutes, or 0 if not locked.
  Future<int> getRemainingLockoutMinutes(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutTime = prefs.getInt(_lockoutKey(email));
    if (lockoutTime == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now > lockoutTime) return 0;
    return ((lockoutTime - now) / 60000).ceil();
  }

  /// Record a failed login attempt. Returns true if account should be locked.
  Future<bool> recordFailedAttempt(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = (prefs.getInt(_attemptsKey(email)) ?? 0) + 1;

    if (attempts >= _maxFailedAttempts) {
      // Lock the account
      final lockoutTime = DateTime.now()
          .add(Duration(minutes: _lockoutDurationMinutes))
          .millisecondsSinceEpoch;
      await prefs.setInt(_lockoutKey(email), lockoutTime);
      return true;
    }

    await prefs.setInt(_attemptsKey(email), attempts);
    return false;
  }

  /// Clear failed attempts on successful login.
  Future<void> clearFailedAttempts(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attemptsKey(email));
  }

  /// Get current failed attempt count.
  Future<int> getFailedAttempts(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_attemptsKey(email)) ?? 0;
  }
}
