import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/constants.dart';
import '../services/storage_service.dart';

class SocketService {
  static IO.Socket? _socket;
  
  static IO.Socket? get socket => _socket;

  // Initialize connection
  static Future<void> connect() async {
    // Feature Flag Guard check
    if (!FeatureFlags.realtimeTracking) {
      print('Socket.io: Connection disabled via FeatureFlags.realtimeTracking');
      return;
    }

    final token = await StorageService.getAccessToken();
    if (token == null) return;

    try {
      _socket = IO.io(Constants.socketUrl, 
        IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .build()
      );

      _socket!.onConnect((_) {
        print('Socket Connected successfully.');
      });

      _socket!.onDisconnect((_) {
        print('Socket Disconnected.');
      });
    } catch (e) {
      print('Socket connection error: $e');
    }
  }

  // Join order room
  static void joinOrderRoom(String orderId) {
    if (!FeatureFlags.realtimeTracking || _socket == null) return;
    _socket!.emit('join:order', orderId);
  }

  // Join order room as technician
  static void joinOrderRoomAsTech(String orderId) {
    if (!FeatureFlags.realtimeTracking || _socket == null) return;
    _socket!.emit('join:order:tech', orderId);
  }

  // Broadcast location updates (Technician)
  static void emitLocation(String orderId, double lat, double lng) {
    if (!FeatureFlags.realtimeTracking || _socket == null) return;
    _socket!.emit('tech:location', {
      'orderId': orderId,
      'lat': lat,
      'lng': lng
    });
  }

  // Disconnect
  static void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
  }
}
