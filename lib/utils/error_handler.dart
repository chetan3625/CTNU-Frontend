import 'dart:async';
import 'package:flutter/material.dart';

class AppErrorHandler {
  static void showError(
    BuildContext context,
    Object error, {
    String? fallbackMessage,
  }) {
    final message = _messageFrom(error, fallbackMessage: fallbackMessage);
    debugPrint('================================================');
    debugPrint('AppErrorHandler: ERROR SHOWED TO USER:');
    debugPrint('Error: $error');
    debugPrint('Message: $message');
    debugPrint('================================================');

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static Widget buildInlineError({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.black87)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  static String _messageFrom(Object error, {String? fallbackMessage}) {
    if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    }

    if (error is FormatException) {
      return 'The server returned an unexpected response.';
    }

    if (error is Exception) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.isNotEmpty && message != 'Exception') {
        return message;
      }
    }

    return fallbackMessage ?? 'Something went wrong. Please try again.';
  }
}
