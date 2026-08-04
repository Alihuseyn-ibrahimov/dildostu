import 'package:flutter/material.dart';

import '../data/settings_repository.dart';
import '../models/app_version_info.dart';
import '../models/settings.dart';
import 'update_banner.dart';

const _minCount = 5;
const _maxCount = 10;

/// Oyanma/yatma vaxtı, gündəlik bildiriş sayı və yeniləmə üçün ekran.
///
/// Yeniləmə axını (yoxla → yüklə → quraşdır) QƏSDƏN Ana səhifədə DEYİL,
/// burada göstərilir — Ana səhifədə dinamik "Yenilə" zolağı Samsung
/// S926B-də bütün Ana səhifə tabını əbədi boş qoyurdu (bax `home_tab.dart`
/// izahı). Bu ekran öz ayrı marşrutudur, o problemi kökündən aradan qaldırır.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    this.buildLabel,
    this.onOpenPrivacyPolicy,
    this.fetchUpdate,
    this.downloadUpdate,
    this.onInstallApk,
  });

  final SettingsRepository repository;

  /// Quraşdırılmış tam versiya (məs. "1.0.0+7") — Android Ayarlar yalnız
  /// versionName-i (həmişə "1.0.0") göstərdiyi üçün buradan görmək lazımdır.
  final String? buildLabel;

  final VoidCallback? onOpenPrivacyPolicy;

  /// Serverdə yeni versiya varmı yoxlayır. `info` yenisi varsa, `error`
  /// yoxlama uğursuz olsa (şəbəkə/403/server) SƏBƏBİ daşıyır — səssiz
  /// uğursuzluq YOX, istifadəçi görməlidir. Null olsa bölmə göstərilmir
  /// (məs. Play buraxılışı).
  final Future<({AppVersionInfo? info, String? error})> Function()?
      fetchUpdate;

  /// APK-nı yükləyir, gedişatı `onProgress`-lə bildirir. Uğursuzsa null.
  final Future<String?> Function(
    void Function(int received, int? total) onProgress,
  )? downloadUpdate;

  /// Yüklənmiş APK-nı sistem quraşdırıcısına açır.
  final Future<void> Function(String path)? onInstallApk;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Settings _settings;

  bool _checkingUpdate = true;
  String? _updateError;
  AppVersionInfo? _availableUpdate;
  UpdateStage _updateStage = UpdateStage.available;
  double? _updateProgress;

  @override
  void initState() {
    super.initState();
    _settings = widget.repository.current;
    if (widget.fetchUpdate != null) _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _updateError = null;
    });
    try {
      final result = await widget.fetchUpdate!();
      if (!mounted) return;
      setState(() {
        _availableUpdate = result.info;
        _updateError = result.error;
        _checkingUpdate = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updateError = '$e';
        _checkingUpdate = false;
      });
    }
  }

  Future<void> _startDownload() async {
    if (widget.downloadUpdate == null) return;
    setState(() {
      _updateStage = UpdateStage.downloading;
      _updateProgress = null;
    });
    var lastPercent = -1;
    final path = await widget.downloadUpdate!((received, total) {
      if (!mounted || total == null || total <= 0) return;
      final percent = received * 100 ~/ total;
      if (percent == lastPercent) return;
      lastPercent = percent;
      setState(() => _updateProgress = received / total);
    });
    if (!mounted) return;
    if (path == null) {
      setState(() {
        _updateStage = UpdateStage.failed;
        _updateProgress = null;
      });
      return;
    }
    setState(() {
      _updateStage = UpdateStage.available;
      _updateProgress = null;
    });
    await widget.onInstallApk?.call(path);
  }

  Future<void> _update(Settings next) async {
    setState(() => _settings = next);
    await widget.repository.save(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Oyanma vaxtı'),
            trailing: Text('${_settings.wakeHour}:00'),
            onTap: () => _pickHour(
              current: _settings.wakeHour,
              onPicked: (h) => _update(Settings(
                wakeHour: h,
                wakeMinute: _settings.wakeMinute,
                sleepHour: _settings.sleepHour,
                sleepMinute: _settings.sleepMinute,
                dailyNotificationCount: _settings.dailyNotificationCount,
              )),
            ),
          ),
          ListTile(
            title: const Text('Yatma vaxtı'),
            trailing: Text('${_settings.sleepHour}:00'),
            onTap: () => _pickHour(
              current: _settings.sleepHour,
              onPicked: (h) => _update(Settings(
                wakeHour: _settings.wakeHour,
                wakeMinute: _settings.wakeMinute,
                sleepHour: h,
                sleepMinute: _settings.sleepMinute,
                dailyNotificationCount: _settings.dailyNotificationCount,
              )),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Gündəlik bildiriş sayı'),
            subtitle: Text('$_minCount–$_maxCount aralığında'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _settings.dailyNotificationCount > _minCount
                      ? () => _update(_withCount(_settings.dailyNotificationCount - 1))
                      : null,
                ),
                Text('${_settings.dailyNotificationCount}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _settings.dailyNotificationCount < _maxCount
                      ? () => _update(_withCount(_settings.dailyNotificationCount + 1))
                      : null,
                ),
              ],
            ),
          ),
          const Divider(),
          if (widget.onOpenPrivacyPolicy != null)
            ListTile(
              title: const Text('Məxfilik siyasəti'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: widget.onOpenPrivacyPolicy,
            ),
          if (widget.buildLabel != null)
            ListTile(
              title: const Text('Buraxılış'),
              trailing: Text(widget.buildLabel!),
            ),
          if (widget.fetchUpdate != null) ...[
            ListTile(
              title: const Text('Yeniləmələr'),
              subtitle: _checkingUpdate
                  ? const Text('Yoxlanılır…')
                  : _availableUpdate != null
                      ? null
                      : _updateError != null
                          ? Text('Yoxlama alınmadı: ${_updateError!}')
                          : const Text('Ən son versiyadasan'),
              trailing: _checkingUpdate
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Yenidən yoxla',
                      onPressed: _checkUpdate,
                    ),
            ),
            // QƏSDƏN Visibility(maintainState: true) — UpdateBanner elementi
            // ilk build-dən sonra HEÇ VAXT unmount/remount olunmur, yalnız
            // görünürlüyü keçir. Əvvəllər `if (_availableUpdate != null)`
            // ilə ListView-un children siyahısına setState-dən sonra DİNAMİK
            // əlavə olunurdu — bu, Samsung S926B-də `home_tab.dart`-da
            // sənədləşmiş eyni "NEEDS-LAYOUT əbədi qalır" bug-ını bu ekranda
            // da təkrarlatdı (yoxlama "yeniləmə tapıldı" göstərirdi — subtitle
            // boş qalırdı — amma banner özü heç görünmürdü). Kök səbəb Home
            // tab-a xas deyilmiş: setState ilə YENİ widget əlavə etmək
            // riskli imiş, hansı ekranda olursa olsun.
            Visibility(
              visible: _availableUpdate != null,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: UpdateBanner(
                    info: _availableUpdate ?? const AppVersionInfo(
                      versionCode: 0,
                      versionName: '',
                    ),
                    onInstall: _startDownload,
                    stage: _updateStage,
                    progress: _updateProgress,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'DilDostu — kontekstli dil öyrənmə köməkçisi',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Settings _withCount(int count) => Settings(
        wakeHour: _settings.wakeHour,
        wakeMinute: _settings.wakeMinute,
        sleepHour: _settings.sleepHour,
        sleepMinute: _settings.sleepMinute,
        dailyNotificationCount: count,
      );

  Future<void> _pickHour({
    required int current,
    required ValueChanged<int> onPicked,
  }) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Saat seçin'),
        children: [
          for (var h = 0; h < 24; h++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(h),
              child: Text('$h:00'),
            ),
        ],
      ),
    );
    if (picked != null) onPicked(picked);
  }
}
