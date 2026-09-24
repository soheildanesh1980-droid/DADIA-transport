import '../config/app_config.dart';

class NetworkConfig {
  static const baseUrl = AppConfig.apiBaseUrl;
  static const connectTimeoutSeconds = 20;
  static const receiveTimeoutSeconds = 30;
  static const maxRetries = 3;
}
