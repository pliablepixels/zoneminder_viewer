import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform;

/// A utility class for handling platform-specific functionality
class PlatformUtils {
  /// Check if the app is running on the web
  static bool get isWeb => kIsWeb;

  /// Check if the app is running on Android
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Check if the app is running on iOS
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Check if the app is running on macOS
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// Check if the app is running on Windows
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// Check if the app is running on Linux
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  /// Check if the app is running on a mobile device (Android or iOS)
  static bool get isMobile => isAndroid || isIOS;

  /// Check if the app is running on a desktop (macOS, Windows, or Linux)
  static bool get isDesktop => isMacOS || isWindows || isLinux;

  /// Get the current platform as a TargetPlatform
  static TargetPlatform get platform {
    if (kIsWeb) {
      return TargetPlatform.android; // Default for web
    }
    
    if (isAndroid) return TargetPlatform.android;
    if (isIOS) return TargetPlatform.iOS;
    if (isMacOS) return TargetPlatform.macOS;
    if (isWindows) return TargetPlatform.windows;
    if (isLinux) return TargetPlatform.linux;
    
    return TargetPlatform.android; // Default fallback
  }

  /// Get the platform name as a string
  static String get platformName {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isMacOS) return 'macOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }

  
  /// Check if the app is running in debug mode
  static bool get isDebugMode {
    bool inDebugMode = false;
    assert(inDebugMode = true);
    return inDebugMode;
  }

  /// Check if the app is running in release mode
  static bool get isReleaseMode => !isDebugMode;

  /// Check if the app is running in profile mode
  static bool get isProfileMode => isReleaseMode && !kDebugMode;

  /// Get the operating system version as a string
  static String get operatingSystemVersion {
    if (kIsWeb) return 'Web';
    return Platform.operatingSystemVersion;
  }

  /// Get the local hostname of the device
  static Future<String> get hostname async {
    if (kIsWeb) return 'web';
    try {
      return await Platform.localHostname;
    } catch (e) {
      return 'unknown';
    }
  }

  /// Check if the app is running on a tablet
  static bool get isTablet {
    if (kIsWeb) return false;
    
    // For Android
    if (isAndroid) {
      // This is a simple check - you might need a more sophisticated approach
      final data = MediaQueryData.fromView(WidgetsBinding.instance.window);
      final size = data.size.shortestSide;
      return size > 550; // Roughly 7" tablet or larger
    }
    
    // For iOS
    if (isIOS) {
      final data = MediaQueryData.fromView(WidgetsBinding.instance.window);
      final size = data.size.shortestSide;
      return size > 550; // Roughly 7" tablet or larger
    }
    
    return false;
  }

  
  /// Get the device pixel ratio
  static double get devicePixelRatio {
    return WidgetsBinding.instance.window.devicePixelRatio;
  }
  
  /// Get the text scale factor
  static double get textScaleFactor {
    return WidgetsBinding.instance.window.textScaleFactor;
  }
  
  /// Get the physical size of the screen in logical pixels
  static Size get screenSize {
    return MediaQueryData.fromView(WidgetsBinding.instance.window).size;
  }
  
  /// Get the physical size of the screen in physical pixels
  static Size get physicalScreenSize {
    final data = MediaQueryData.fromView(WidgetsBinding.instance.window);
    return Size(
      data.size.width * data.devicePixelRatio,
      data.size.height * data.devicePixelRatio,
    );
  }
  
  /// Get the padding around the app (status bar, notches, etc.)
  static EdgeInsets get padding {
    return MediaQueryData.fromView(WidgetsBinding.instance.window).padding;
  }
  
  /// Get the view insets (keyboard, system UI, etc.)
  static EdgeInsets get viewInsets {
    return MediaQueryData.fromView(WidgetsBinding.instance.window).viewInsets;
  }
  
  /// Check if the device is in landscape orientation
  static bool get isLandscape {
    final data = MediaQueryData.fromView(WidgetsBinding.instance.window);
    return data.orientation == Orientation.landscape;
  }
  
  /// Check if the device is in portrait orientation
  static bool get isPortrait => !isLandscape;
  
  /// Check if the device has a notch or other display cutout
  static bool get hasNotch {
    if (kIsWeb) return false;
    
    final data = MediaQueryData.fromView(WidgetsBinding.instance.window);
    return data.padding.top > 24.0; // Arbitrary value to detect notch
  }
  
  /// Get the status bar height
  static double get statusBarHeight {
    return MediaQueryData.fromView(WidgetsBinding.instance.window).padding.top;
  }
  
  /// Get the bottom safe area (for devices with a home indicator)
  static double get bottomSafeArea {
    return MediaQueryData.fromView(WidgetsBinding.instance.window).padding.bottom;
  }
}

/// Extension to get platform-specific values
extension PlatformExtension on TargetPlatform {
  /// Check if the platform is a mobile platform
  bool get isMobile => this == TargetPlatform.android || this == TargetPlatform.iOS;
  
  /// Check if the platform is a desktop platform
  bool get isDesktop =>
      this == TargetPlatform.macOS ||
      this == TargetPlatform.windows ||
      this == TargetPlatform.linux;
  
  /// Get the platform name as a string
  String get name {
    switch (this) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }
}
