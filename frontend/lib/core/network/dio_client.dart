import 'package:dio/dio.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/core/security/secure_storage.dart';

class DioClient {
  late final Dio _dio;

  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(_dio));
  }

  Dio get dio => _dio;
}

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  _AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorageService.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (error.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await SecureStorageService.getRefreshToken();
        if (refreshToken == null) {
          handler.next(error);
          return;
        }

        final response = await _dio.post(
          ApiConstants.refreshToken,
          data: {'refresh_token': refreshToken},
        );

        final newAccessToken = response.data['access_token'] as String?;
        if (newAccessToken == null) {
          await SecureStorageService.clearAll();
          handler.next(error);
          return;
        }

        await SecureStorageService.saveAccessToken(newAccessToken);

        // Retry original request
        final opts = error.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newAccessToken';
        final retried = await _dio.fetch(opts);
        handler.resolve(retried);
      } catch (_) {
        await SecureStorageService.clearAll();
        handler.next(error);
      } finally {
        _isRefreshing = false;
      }
    } else {
      handler.next(error);
    }
  }
}
