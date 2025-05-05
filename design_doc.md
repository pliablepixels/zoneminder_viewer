# ZoneMinder Viewer - Design Document

*Note: This document was AI-generated based on the current state of the codebase.*

## Overview

ZoneMinder Viewer is a Flutter mobile application that provides a modern interface for viewing and interacting with ZoneMinder, an open-source video surveillance system. The app allows users to connect to ZoneMinder servers, view live camera feeds, and monitor security events.

## Architecture

The application follows a standard Flutter architecture with clear separation of concerns:

1. **Presentation Layer**
   - Views: UI components and screens
   - Widgets: Reusable UI components
   - State Management: Built-in Flutter state management

2. **Business Logic Layer**
   - Services: Handle API communication and business logic
   - Models: Data structures and business objects

3. **Data Layer**
   - Local Storage: Using SharedPreferences for persistence
   - Remote API: Communication with ZoneMinder server

## Key Components

### 1. ZoneMinderService

Located in `lib/services/zoneminder_service.dart`, this is the core service that handles all communication with the ZoneMinder server.

**Key Features:**
- Manages authentication (access tokens, refresh tokens)
- Handles API requests to the ZoneMinder server
- Implements URL sanitization and request building
- Manages persistent storage of server configuration
- Provides methods for:
  - Authentication
  - Retrieving monitors/feeds
  - Managing events
  - System status checks

### 2. MJPEG Viewer

Located in `lib/widgets/mjpeg_view.dart`, this widget handles the display of MJPEG video streams from ZoneMinder cameras.

**Key Features:**
- Uses WebView for cross-platform MJPEG streaming
- Handles different platforms (iOS/Android) with platform-specific configurations
- Implements error handling and loading states
- Supports different display modes (fit, fill, etc.)
- Handles authentication for protected streams

### 3. Main Application Structure

**Main Application (`main.dart`)**
- Sets up the Flutter application
- Configures theming and navigation
- Initializes logging

**Views:**
- `WizardView`: Initial setup and configuration
- `MonitorView`: Displays camera feeds
- `EventsView`: Shows recorded events and alerts

## Technical Stack

- **Framework**: Flutter (Dart)
- **State Management**: Built-in Flutter state management
- **HTTP Client**: `http` package for API requests
- **Local Storage**: `shared_preferences` for persistent storage
- **WebView**: `webview_flutter` for MJPEG streaming
- **Logging**: Built-in `logging` package

## Authentication Flow

1. User enters ZoneMinder server URL
2. App attempts to connect and authenticate
3. On successful authentication, tokens are stored securely
4. Subsequent requests include the access token
5. Token refresh is handled automatically when needed

## Data Flow

1. **Initialization**:
   - App loads saved configuration from SharedPreferences
   - ZoneMinderService initializes with saved URL and tokens

2. **Viewing Feeds**:
   - User navigates to MonitorView
   - App fetches list of available monitors from ZoneMinder
   - MjpegView widgets are created for each monitor
   - Each MjpegView establishes a WebView connection to the MJPEG stream

3. **Viewing Events**:
   - User navigates to EventsView
   - App fetches events from ZoneMinder
   - Events are displayed in a list
   - Users can select events to view details or playback

## Error Handling

- Network errors are caught and displayed to the user
- Authentication failures trigger re-authentication flow
- Invalid URLs are sanitized and validated
- Loading and error states are clearly indicated in the UI

## Security Considerations

- HTTPS is enforced for all API communications
- Authentication tokens are stored securely
- URL sanitization prevents injection attacks
- WebView is configured with appropriate security settings

## Future Enhancements

1. **Offline Mode**: Cache camera feeds and events for offline viewing
2. **Push Notifications**: Alert users to motion events
3. **Multi-server Support**: Connect to multiple ZoneMinder servers
4. **Advanced Playback Controls**: For recorded events
5. **Customizable Layouts**: Grid view, split screen, etc.

## Dependencies

- `http`: ^1.3.0
- `shared_preferences`: ^2.2.0
- `logging`: ^1.0.28
- `webview_flutter`: ^4.4.2
- `webview_flutter_android`: ^3.10.2
- `webview_flutter_wkwebview`: ^3.6.3
- `webview_flutter_platform_interface`: ^2.1.0

## Platform Support

The application is designed to work on both iOS and Android platforms, with platform-specific implementations for WebView handling.
