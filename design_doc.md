# ZoneMinder Viewer - Code Architecture

*Document last updated: May 2024*

## Project Structure

```
lib/
├── core/
│   ├── constants/       # Application-wide constants
│   ├── errors/          # Custom exceptions and error handling
│   ├── services/        # Core services (API client, etc.)
│   ├── utils/           # Utility classes and helpers
│   └── widgets/         # Reusable UI components
├── features/
│   ├── auth/            # Authentication feature
│   │   ├── data/
│   │   │   ├── datasources/  # Data sources (local/remote)
│   │   │   └── repositories/  # Repository implementations
│   │   ├── domain/
│   │   │   ├── entities/    # Business objects
│   │   │   ├── repositories/  # Repository interfaces
│   │   │   └── usecases/     # Business logic
│   │   └── presentation/     # UI layer for auth
│   └── ... (other features follow same structure)
├── main.dart            # Application entry point
└── service_locator.dart # Dependency injection setup
```

## Architecture Overview

The application follows Clean Architecture principles with a clear separation of concerns:

1. **Presentation Layer**
   - UI Components (Widgets)
   - State Management (Provider/Riverpod)
   - Navigation

2. **Domain Layer**
   - Business logic
   - Use cases
   - Repository interfaces
   - Entities

3. **Data Layer**
   - Repository implementations
   - Data sources (local/remote)
   - Data models
   - Mappers

## Key Components

### 1. Dependency Injection (Service Locator)

**Location**: `lib/service_locator.dart`

- Centralized dependency management using GetIt
- Handles singleton creation and lifecycle
- Organized by feature and layer
- Supports different environments (dev, prod, test)

### 2. Authentication Feature

#### Data Layer
- **AuthRemoteDataSource**: Handles API communication
- **AuthLocalDataSource**: Manages local storage (tokens, credentials)
- **AuthRepositoryImpl**: Implements auth repository interface

#### Domain Layer
- **AuthRepository**: Defines auth operations
- **AuthUseCases**: Business logic (login, logout, validate session)
- **Entities**: User, AuthResponse, AuthCredentials

#### Presentation Layer
- **AuthBloc/Cubit**: Manages auth state
- **LoginScreen**: Login UI
- **AuthWrapper**: Handles auth state-based routing

### 3. Core Services

#### API Client
- **ApiClient**: Wrapper around Dio for HTTP requests
- **Interceptors**: For auth, logging, error handling
- **Request/Response models**

#### Storage
- **StorageUtils**: Unified storage interface
  - Secure storage for sensitive data
  - Shared preferences for non-sensitive data
  - Type-safe accessors

### 4. Error Handling

- **AppException**: Base exception class
- **NetworkException**: For API/network issues
- **StorageException**: For data persistence errors
- **Error handling middleware** in API client

## Data Flow

1. **Authentication**
   ```dart
   UI -> AuthBloc -> LoginUseCase -> AuthRepository -> DataSources -> API/Storage
   ```

2. **Data Fetching**
   ```dart
   UI -> Bloc -> UseCase -> Repository -> DataSource -> API -> Parse -> Return
   ```

## Testing Strategy

- **Unit Tests**: For use cases, repositories, utilities
- **Widget Tests**: For UI components
- **Integration Tests**: For complete features
- **Mocks**: Using Mockito for dependencies

## Code Organization Principles

1. **Feature-first** organization
2. **Single Responsibility**: Each class has one reason to change
3. **Dependency Rule**: Dependencies point inward (Domain ← Data ← Presentation)
4. **Immutability**: Use `freezed` for immutable models
5. **Null Safety**: Full null-safety compliance

## Dependencies

- **State Management**: flutter_bloc, riverpod
- **Networking**: dio, retrofit
- **Storage**: shared_preferences, flutter_secure_storage
- **DI**: get_it, injectable
- **Testing**: mockito, bloc_test, flutter_test
- **Code Generation**: json_serializable, freezed, injectable_generator

## Development Workflow

1. Create/update domain models and repository interfaces
2. Implement data layer (API clients, mappers)
3. Implement use cases
4. Create/update UI components
5. Write tests
6. Update documentation

## Best Practices

- Follows BLoC pattern for state management
- Immutable state
- Repository pattern for data access
- Dependency injection for testability
- Comprehensive error handling
- Logging for debugging
- Documentation for public APIs
