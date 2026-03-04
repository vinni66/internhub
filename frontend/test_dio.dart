import 'package:dio/dio.dart';

void main() {
  final dio =
      Dio(BaseOptions(baseUrl: 'https://internhub-bn09.onrender.com/api/v1'));

  // Register an interceptor just to print the requested URI and block it
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      print('URL RESOLVED TO: \${options.uri}');
      handler.reject(DioException(requestOptions: options, error: 'Blocked'));
    },
  ));

  dio.post('/upload/image').catchError((e) => print('Done'));
  dio.post('/auth/login').catchError((e) => print('Done'));
}
