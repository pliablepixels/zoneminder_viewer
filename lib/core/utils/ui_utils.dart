import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

/// A utility class for common UI operations
class UiUtils {
  static final Logger _logger = Logger('UiUtils');

  /// Hides the keyboard if it's visible
  static void hideKeyboard(BuildContext context) {
    try {
      final currentFocus = FocusScope.of(context);
      if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    } catch (e, stackTrace) {
      _logger.warning('Failed to hide keyboard', e, stackTrace);
    }
  }

  /// Shows a snackbar with the given message
  static void showSnackBar(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
    Color? backgroundColor,
    Color? textColor,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    try {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: textColor != null ? TextStyle(color: textColor) : null,
          ),
          duration: duration,
          backgroundColor: backgroundColor,
          action: actionLabel != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: textColor,
                  onPressed: onActionPressed ?? () {},
                )
              : null,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      );
    } catch (e, stackTrace) {
      _logger.warning('Failed to show snackbar', e, stackTrace);
    }
  }

  /// Shows a confirmation dialog
  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool barrierDismissible = true,
    Color? confirmButtonColor,
    Color? cancelButtonColor,
  }) async {
    try {
      if (!context.mounted) return null;
      
      return await showDialog<bool>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: cancelButtonColor,
              ),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: confirmButtonColor,
              ),
              child: Text(confirmText),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      _logger.warning('Failed to show confirmation dialog', e, stackTrace);
      return null;
    }
  }

  /// Shows a loading dialog
  static void showLoadingDialog(
    BuildContext context, {
    String message = 'Loading...',
    bool barrierDismissible = false,
  }) {
    try {
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (context) => PopScope(
          canPop: barrierDismissible,
          child: AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16.0),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
      );
    } catch (e, stackTrace) {
      _logger.warning('Failed to show loading dialog', e, stackTrace);
    }
  }

  /// Hides the current dialog if one is shown
  static void hideDialog(BuildContext context) {
    try {
      if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e, stackTrace) {
      _logger.warning('Failed to hide dialog', e, stackTrace);
    }
  }

  /// Copies text to clipboard and shows a snackbar
  static void copyToClipboard(
    BuildContext context, {
    required String text,
    String? successMessage,
  }) {
    try {
      Clipboard.setData(ClipboardData(text: text));
      
      if (context.mounted) {
        showSnackBar(
          context,
          message: successMessage ?? 'Copied to clipboard',
        );
      }
    } catch (e, stackTrace) {
      _logger.warning('Failed to copy to clipboard', e, stackTrace);
      
      if (context.mounted) {
        showSnackBar(
          context,
          message: 'Failed to copy to clipboard',
        );
      }
    }
  }

  /// Gets the icon data for a given file extension
  static IconData getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
      case 'webm':
        return Icons.video_library;
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'm4a':
        return Icons.audiotrack;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Creates a shimmer effect for loading states
  static Widget buildShimmerEffect({
    double width = double.infinity,
    double height = double.infinity,
    double borderRadius = 4.0,
    BoxShape shape = BoxShape.rectangle,
    Color? baseColor,
    Color? highlightColor,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor ?? Colors.grey[300],
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        shape: shape,
      ),
      child: highlightColor != null
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return ShaderMask(
                  shaderCallback: (rect) => LinearGradient(
                    colors: [
                      baseColor ?? Colors.grey[300]!,
                      highlightColor,
                      baseColor ?? Colors.grey[300]!,
                    ],
                    stops: [
                      value - 0.5,
                      value,
                      value + 0.5,
                    ],
                  ).createShader(rect),
                  child: child,
                );
              },
              child: Container(
                width: width,
                height: height,
                color: Colors.white,
              ),
            )
          : null,
    );
  }

  /// Creates a responsive layout that adapts to screen size
  static T responsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final data = MediaQuery.of(context);
    final width = data.size.width;

    // Mobile: width < 600
    if (width < 600) return mobile;
    
    // Tablet: 600 <= width < 900
    if (width < 900) return tablet ?? mobile;
    
    // Desktop: width >= 900
    return desktop ?? tablet ?? mobile;
  }

  /// Creates a responsive grid layout
  static int responsiveGridCount({
    required BuildContext context,
    int mobile = 1,
    int? tablet,
    int? desktop,
    int? largeDesktop,
  }) {
    final data = MediaQuery.of(context);
    final width = data.size.width;

    if (width < 600) return mobile; // Mobile
    if (width < 900) return tablet ?? mobile * 2; // Tablet
    if (width < 1200) return desktop ?? tablet ?? mobile * 3; // Desktop
    return largeDesktop ?? desktop ?? tablet ?? mobile * 4; // Large desktop
  }
}
