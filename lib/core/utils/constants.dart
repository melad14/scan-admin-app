class Constants {
  // Base API URLs
  static const String apiBaseUrl = 'http://localhost:3000/api/v1';
  static const String socketUrl = 'http://localhost:3000';

  // Endpoints
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String register = '/auth/register';
  static const String loginTech = '/auth/technician/login';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';
  
  static const String services = '/services';
  static const String orders = '/orders';
  static const String ordersHistory = '/orders/history';
  
  static const String techAvailableOrders = '/technician/orders/available';
  static const String techActiveOrder = '/technician/orders/active';
  static const String techOrdersHistory = '/technician/orders/history';
  static const String techLocation = '/technician/location';
  static const String techAvailability = '/technician/availability';
}

class FeatureFlags {
  // Flag controls whether live tracking map moves via socket
  static const bool realtimeTracking =
      bool.fromEnvironment('REALTIME_TRACKING_ENABLED', defaultValue: false);
}
