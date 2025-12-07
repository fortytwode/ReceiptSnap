import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_config.dart';
import 'storage_service.dart';

/// API Client using Dio for HTTP requests
class ApiClient {
  final Dio _dio;
  final StorageService _storage;

  ApiClient(this._storage)
      : _dio = Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: Duration(seconds: ApiConfig.timeout),
            receiveTimeout: Duration(seconds: ApiConfig.timeout),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add auth token if available
          final token = _storage.authToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Add device ID for anonymous auth
          final userId = _storage.userId;
          if (userId != null) {
            options.headers['X-Device-ID'] = userId;
          }

          return handler.next(options);
        },
        onError: (error, handler) {
          // Handle common errors
          if (error.response?.statusCode == 401) {
            // TODO: Handle unauthorized - clear auth and redirect to login
          }
          return handler.next(error);
        },
      ),
    );

    // Add logging in debug mode
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print('API: $obj'),
      ),
    );
  }

  // GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  // POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.post<T>(path, data: data, queryParameters: queryParameters);
  }

  // PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.put<T>(path, data: data, queryParameters: queryParameters);
  }

  // DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.delete<T>(path, queryParameters: queryParameters);
  }

  // Multipart file upload
  Future<Response<T>> uploadFile<T>(
    String path, {
    required String filePath,
    required String fieldName,
    Map<String, dynamic>? additionalFields,
  }) async {
    final formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath),
      if (additionalFields != null) ...additionalFields,
    });

    return _dio.post<T>(path, data: formData);
  }
}

/// Provider for ApiClient
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiClient(storage);
});
