import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dr_ray_technician/core/services/notification_service.dart'
    show notificationNavigatorKey;
import 'package:dr_ray_technician/core/utils/constants.dart';

/// In-app update check.
///
/// On launch (and when the app returns to the foreground) asks
/// `GET /app-version?app=…&versionCode=…` whether a newer build was published
/// from the dashboard (Settings → App Updates). If so it shows a dialog whose
/// "Update" button opens the published link (e.g. a Google Drive link to the APK).
/// When the server says the build is below the minimum supported one, the
/// dialog can't be dismissed.
class UpdateService {
  static const String _app = 'technician';

  static DateTime? _lastCheck;
  static bool _dialogOpen = false;
  static bool _forced = false;
  static int? _dismissedVersionCode;
  static AppLifecycleListener? _lifecycleListener;

  /// Call once after runApp().
  static void start() {
    if (kIsWeb) return;
    _lifecycleListener ??= AppLifecycleListener(onResume: () {
      check();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Let the router mount its first screen before showing a dialog
      Future.delayed(const Duration(seconds: 2), check);
    });
  }

  static Future<void> check() async {
    if (kIsWeb || _dialogOpen) return;
    final last = _lastCheck;
    // A forced update is re-checked on every resume; otherwise at most every 6h
    if (!_forced && last != null && DateTime.now().difference(last).inHours < 6) {
      return;
    }
    _lastCheck = DateTime.now();

    try {
      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;

      final dio = Dio(BaseOptions(
        baseUrl: Constants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final res = await dio.get('/app-version', queryParameters: {
        'app': _app,
        'versionCode': currentCode,
      });

      final data = (res.data is Map) ? res.data['data'] : null;
      if (data is! Map || data['updateAvailable'] != true) {
        _forced = false;
        return;
      }

      final force = data['forceUpdate'] == true;
      final latestCode = (data['versionCode'] as num?)?.toInt();
      final url = data['updateUrl']?.toString() ?? '';
      if (!url.startsWith('https://')) return;
      if (!force && latestCode != null && latestCode == _dismissedVersionCode) {
        return;
      }

      final context = notificationNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      _forced = force;
      _dialogOpen = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: !force,
        builder: (ctx) => _UpdateDialog(
          force: force,
          versionName: data['versionName']?.toString() ?? '',
          notes: data['releaseNotesAr']?.toString() ?? '',
          url: url,
        ),
      );
      _dialogOpen = false;
      if (!force) _dismissedVersionCode = latestCode;
    } catch (e) {
      _dialogOpen = false;
      debugPrint('[UpdateService] check failed: $e');
    }
  }
}

class _UpdateDialog extends StatelessWidget {
  final bool force;
  final String versionName;
  final String notes;
  final String url;

  const _UpdateDialog({
    required this.force,
    required this.versionName,
    required this.notes,
    required this.url,
  });

  Future<void> _openUpdate(BuildContext context) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('تعذر فتح رابط التحديث')),
      );
    }
    // A forced update keeps the dialog up until the new build is installed
    if (!force && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !force,
      child: AlertDialog(
        title: Text(force ? 'تحديث مطلوب' : 'تحديث جديد متاح'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(versionName.isNotEmpty
                ? 'الإصدار $versionName متاح الآن.'
                : 'يتوفر إصدار جديد من التطبيق.'),
            if (force) ...[
              const SizedBox(height: 8),
              const Text('يجب تحديث التطبيق للاستمرار في استخدامه.'),
            ],
            if (notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(notes, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('لاحقاً'),
            ),
          FilledButton(
            onPressed: () => _openUpdate(context),
            child: const Text('تحديث الآن'),
          ),
        ],
      ),
    );
  }
}
