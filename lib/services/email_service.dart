import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service for sending emails via EmailJS
class EmailService {
  // EmailJS configuration
  static final String _publicKey = dotenv.env['EMAILJS_PUBLIC_KEY'] ?? '';
  static final String _serviceId = dotenv.env['EMAILJS_SERVICE_ID'] ?? '';
  static final String _templateId = dotenv.env['EMAILJS_TEMPLATE_ID'] ?? '';
  
  static const String _emailJsUrl = 'https://api.emailjs.com/api/v1.0/email/send';
  
  String? _lastError;
  String? get lastError => _lastError;

  /// Send OTP via email
  Future<bool> sendOTPEmail({
    required String userEmail,
    required String otp,
    required String userName,
  }) async {
    try {
      _lastError = null;

      // Validate configuration
      if (_publicKey.isEmpty || _publicKey.startsWith('YOUR_')) {
        _lastError = 'EmailJS configuration not set. Please add EMAILJS_PUBLIC_KEY to .env file';
        print('Error: $_lastError');
        return false;
      }

      if (_serviceId.isEmpty || _serviceId.startsWith('YOUR_')) {
        _lastError = 'EmailJS service ID not configured. Please add EMAILJS_SERVICE_ID to .env file';
        print('Error: $_lastError');
        return false;
      }

      if (_templateId.isEmpty || _templateId.startsWith('YOUR_')) {
        _lastError = 'EmailJS template ID not configured. Please add EMAILJS_TEMPLATE_ID to .env file';
        print('Error: $_lastError');
        return false;
      }

      // Prepare email data
      final emailData = <String, dynamic>{
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {
          'email': userEmail,
          'passcode': otp,
          'time': '15 minutes',
        },
      };

      print('Sending OTP email to: $userEmail');
      print('Request URL: $_emailJsUrl');
      print('Service ID: $_serviceId');
      print('Template ID: $_templateId');
      print('Public Key: ${_publicKey.substring(0, 5)}...');

      // Send request
      final response = await http
          .post(
            Uri.parse(_emailJsUrl),
            headers: {
              'Content-Type': 'application/json',
              'origin': 'http://localhost',
            },
            body: jsonEncode(emailData),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              _lastError = 'Email send request timed out';
              return http.Response('Timeout', 408);
            },
          );

      print('EmailJS Response Status: ${response.statusCode}');
      print('EmailJS Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ OTP email sent successfully to $userEmail');
        return true;
      } else if (response.statusCode == 400) {
        _lastError = 'Bad request. Check EmailJS configuration: ${response.body}';
      } else if (response.statusCode == 401) {
        _lastError = 'Unauthorized. Invalid EmailJS credentials: ${response.body}';
      } else if (response.statusCode == 429) {
        _lastError = 'Too many requests. Please try again later';
      } else {
        _lastError = 'Failed to send email. Status: ${response.statusCode}, Response: ${response.body}';
      }

      print('❌ Error sending email: $_lastError');
      return false;
    } catch (e) {
      _lastError = 'Error sending OTP email: $e';
      print('❌ Exception: $_lastError');
      return false;
    }
  }

  /// Send password reset confirmation email
  Future<bool> sendPasswordResetEmail({
    required String userEmail,
    required String userName,
  }) async {
    try {
      _lastError = null;

      // Validate configuration
      if (_publicKey.isEmpty || _publicKey.startsWith('YOUR_')) {
        _lastError = 'EmailJS not configured. Add EMAILJS_PUBLIC_KEY to .env';
        return false;
      }

      final emailData = <String, dynamic>{
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {
          'user_email': userEmail,
          'user_name': userName,
          'app_name': 'Fitness Tracker',
          'reset_type': 'confirmation',
        },
      };

      final response = await http
          .post(
            Uri.parse(_emailJsUrl),
            headers: {
              'Content-Type': 'application/json',
              'origin': 'http://localhost',
            },
            body: jsonEncode(emailData),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Password reset confirmation email sent to $userEmail');
        return true;
      } else {
        _lastError = 'Failed to send confirmation email';
        return false;
      }
    } catch (e) {
      _lastError = 'Error sending confirmation email: $e';
      return false;
    }
  }

  /// Verify EmailJS configuration
  static Future<bool> verifyConfiguration() async {
    try {
      if (_publicKey.isEmpty || _publicKey.startsWith('YOUR_')) {
        print('❌ EMAILJS_PUBLIC_KEY not configured');
        return false;
      }
      if (_serviceId.isEmpty || _serviceId.startsWith('YOUR_')) {
        print('❌ EMAILJS_SERVICE_ID not configured');
        return false;
      }
      if (_templateId.isEmpty || _templateId.startsWith('YOUR_')) {
        print('❌ EMAILJS_TEMPLATE_ID not configured');
        return false;
      }

      print('✅ EmailJS configuration verified');
      return true;
    } catch (e) {
      print('Error verifying configuration: $e');
      return false;
    }
  }
}
