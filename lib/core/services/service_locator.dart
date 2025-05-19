import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';

import 'package:zoneminder_viewer/core/services/api_client.dart';
import 'package:zoneminder_viewer/core/utils/storage_utils.dart';
import 'package:zoneminder_viewer/core/utils/logger_util.dart';
import 'package:zoneminder_viewer/core/constants/app_constants.dart';

// Data Sources
import 'package:zoneminder_viewer/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:zoneminder_viewer/features/auth/data/datasources/auth_remote_data_source.dart';

// Repositories
import 'package:zoneminder_viewer/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:zoneminder_viewer/features/auth/domain/repositories/auth_repository.dart';

/// Service locator for dependency injection
final GetIt sl = GetIt.instance;

/// Initializes all the services and their dependencies
Future<void> initServiceLocator() async {
  await _registerCore();
  await _registerDataSources();
  await _registerRepositories();
  await _registerServices();
  await _registerViewModels();
}

/// Registers core dependencies
Future<void> _registerCore() async {
  // Logger
  sl.registerLazySingleton<Logger>(() => Logger('ZoneMinderViewer'));
  
  // SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  
  // Storage Utils
  sl.registerLazySingleton<StorageUtils>(
    () => StorageUtils(
      sharedPreferences: sl(),
      logger: sl(),
    ),
  );
  
  // Connectivity
  sl.registerLazySingleton<Connectivity>(() => Connectivity());
  
  // API Client
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(
      baseUrl: AppConstants.apiBaseUrl,
      enableLogging: !AppConstants.isReleaseMode,
    ),
  );
}

/// Registers data sources
Future<void> _registerDataSources() async {
  // Auth Remote Data Source
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      apiClient: sl(),
      logger: sl(),
    ),
  );

  // Auth Local Data Source
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(
      storage: sl(),
      logger: sl(),
    ),
  );
}

/// Registers repositories
Future<void> _registerRepositories() async {
  // Auth Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      apiClient: sl(),
      logger: sl(),
    ),
  );
}

/// Registers services
Future<void> _registerServices() async {
  // Register your services here
  // Example:
  // sl.registerLazySingleton<AuthService>(
  //   () => AuthServiceImpl(
  //     authRepository: sl(),
  //     logger: sl(),
  //   ),
  // );
}

/// Registers view models
Future<void> _registerViewModels() async {
  // Register your view models here
  // Example:
  // sl.registerFactory<LoginViewModel>(
  //   () => LoginViewModel(
  //     authRepository: sl(),
  //     logger: sl(),
  //   ),
  // );
}

/// Gets an instance of type T from the service locator
T getIt<T extends Object>({
  String? instanceName,
  dynamic param1,
  dynamic param2,
}) {
  return sl.get<T>(
    instanceName: instanceName,
    param1: param1,
    param2: param2,
  );
}

/// Resets the service locator (for testing)
Future<void> resetServiceLocator() async {
  await sl.reset(dispose: true);
  await initServiceLocator();
}
