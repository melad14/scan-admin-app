import 'package:dio/dio.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

class ApiClient {
  final Dio dio = Dio(BaseOptions(
    baseUrl: Constants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Language': 'ar',
    },
  ));

  ApiClient() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Retrieve token from SharedPreferences
          final token = await StorageService.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Catch unauthorized 401 response and trigger token refresh rotation
          if (error.response?.statusCode == 401) {
            final refreshToken = await StorageService.getRefreshToken();
            
            if (refreshToken != null) {
              try {
                // Spawn a new clean Dio instance to avoid recursive loops
                final refreshDio = Dio();
                final refreshRes = await refreshDio.post(
                  '${Constants.apiBaseUrl}${Constants.refreshToken}',
                  data: {'refreshToken': refreshToken},
                );

                if (refreshRes.statusCode == 200 && refreshRes.data['success'] == true) {
                  final newAccessToken = refreshRes.data['data']['accessToken'];
                  final newRefreshToken = refreshRes.data['data']['refreshToken'];

                  // Persist new rotated tokens
                  await StorageService.saveAccessToken(newAccessToken);
                  await StorageService.saveRefreshToken(newRefreshToken);

                  // Retry the original failed request with the new access token
                  final originalOptions = error.requestOptions;
                  originalOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                  
                  final retryResponse = await dio.fetch(originalOptions);
                  return handler.resolve(retryResponse);
                }
              } catch (refreshError) {
                // If refresh token has expired or is invalid, perform clean logout
                await StorageService.clearAll();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
}
