import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

class SocketConfig {
  static String get socketUrl {
    try {
      return dotenv.env['SOCKET_URL'] ?? 'https://ctnu-backend.onrender.com';
    } catch (_) {
      return 'https://ctnu-backend.onrender.com';
    }
  }

  static socket_io.Socket create(String token) {
    return socket_io.io(
      socketUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableForceNew()
          .disableAutoConnect()
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(3000)
          .setTimeout(15000)
          .build(),
    );
  }
}
