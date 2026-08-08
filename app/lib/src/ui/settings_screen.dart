import 'package:flutter/material.dart';

import '../l10n/app_locale_scope.dart';
import '../models/ui_language.dart';
import '../data/settings_repository.dart';
import '../data/device_lock_repository.dart';
import '../data/tts_telemetry_repository.dart';
import '../models/app_version_info.dart';
import '../models/audiobook.dart';
import '../models/chat_quota.dart';
import '../models/settings.dart';
import '../services/audiobook_downloader.dart';
import 'update_banner.dart';
import 'unlock_screen.dart';

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
    this.ttsTelemetry,
    this.audiobookDownloader,
    this.loadAudiobookLibrary,
    this.onDownloadAudiobooks,
    this.loadChatPortrait,
    this.loadChatQuota,
    this.lockRepo,
    this.onRescheduleNotifications,
    this.onClearChatHistory,
    this.onClearChatPortrait,
    this.onUiLanguageChanged,
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

  /// Faza 0 (ElevenLabs planı) baseline ölçüsü — `flutter_tts`-in cihazda
  /// nə qədər uğursuz olduğu. Null olsa bölmə göstərilmir.
  final TtsTelemetry? ttsTelemetry;
  // Dil seçicisi burada QƏSDƏN yoxdur — ana səhifənin sağ yuxarı küncünə
  // köçürülüb (`home_tab.dart`, `_LanguagePicker`) ki, hər dəfə Ayarlara
  // girmək lazım gəlməsin.

  /// Offline endirmə vəziyyəti (bax `AudiobookDownloader`) — `ChangeNotifier`
  /// olduğu üçün `ListenableBuilder` ilə canlı izlənir. Null olsa bölmə
  /// göstərilmir.
  final AudiobookDownloader? audiobookDownloader;

  /// İstifadəçinin dilinə uyğun səsli kitab kitabxanası (endirilməli ölçünü
  /// hesablamaq üçün).
  final Future<List<Audiobook>> Function()? loadAudiobookLibrary;

  /// Endirməni başladır — `audiobookDownloader.downloadAll`-a bağlanır.
  final Future<void> Function(List<Audiobook> books)? onDownloadAudiobooks;

  /// AI-nin istifadəçi haqqında yığdığı faktlar (şəffaflıq bölməsi).
  /// Null olsa "AI yaddaşı" bölməsi göstərilmir.
  final Future<List<String>> Function()? loadChatPortrait;

  /// Gündəlik söhbət kvotası — AI yaddaşı bölməsində göstərilir.
  final Future<ChatQuota?> Function()? loadChatQuota;

  /// Cihaz kilidi (PIN/biometrik) — Ayarlarda idarə olunur.
  final DeviceLockRepository? lockRepo;

  /// Oyanma/yatma/say dəyişəndə bildiriş cədvəlini yeniləyir.
  final Future<void> Function()? onRescheduleNotifications;

  /// Söhbət tarixçəsini serverdə silir (portret qalır).
  final Future<bool> Function()? onClearChatHistory;

  /// AI-nin yığdığı portreti silir (tarixçə qalır).
  final Future<bool> Function()? onClearChatPortrait;

  /// Proqram interfeys dili dəyişəndə — `MaterialApp` locale yenilənir.
  final ValueChanged<UiLanguage>? onUiLanguageChanged;

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
    await widget.onRescheduleNotifications?.call();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(s.appLanguage),
            subtitle: Text(s.appLanguageHint),
            trailing: Text(_settings.uiLanguage.nativeLabel),
            onTap: widget.onUiLanguageChanged == null
                ? null
                : () => _pickUiLanguage(context),
          ),
          const Divider(),
          ListTile(
            title: Text(s.wakeTime),
            trailing: Text('${_settings.wakeHour}:00'),
            onTap: () => _pickHour(
              current: _settings.wakeHour,
              onPicked: (h) => _update(_settings.copyWith(wakeHour: h)),
            ),
          ),
          ListTile(
            title: Text(s.sleepTime),
            trailing: Text('${_settings.sleepHour}:00'),
            onTap: () => _pickHour(
              current: _settings.sleepHour,
              onPicked: (h) => _update(_settings.copyWith(sleepHour: h)),
            ),
          ),
          const Divider(),
          ListTile(
            title: Text(s.dailyNotifications),
            subtitle: Text(s.notificationRange(_minCount, _maxCount)),
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
              title: Text(s.privacyPolicy),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: widget.onOpenPrivacyPolicy,
            ),
          if (widget.buildLabel != null)
            ListTile(
              title: Text(s.releaseLabel),
              trailing: Text(widget.buildLabel!),
            ),
          if (widget.fetchUpdate != null) ...[
            ListTile(
              title: Text(s.updates),
              subtitle: _checkingUpdate
                  ? Text(s.checkingUpdates)
                  : _availableUpdate != null
                      ? null
                      : _updateError != null
                          ? Text(s.updateCheckFailed(_updateError!))
                          : Text(s.upToDate),
              trailing: _checkingUpdate
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: s.recheckUpdates,
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
          if (widget.audiobookDownloader != null &&
              widget.loadAudiobookLibrary != null &&
              widget.onDownloadAudiobooks != null) ...[
            const Divider(),
            _OfflineAudiobooksSection(
              downloader: widget.audiobookDownloader!,
              loadLibrary: widget.loadAudiobookLibrary!,
              onDownload: widget.onDownloadAudiobooks!,
            ),
          ],
          if (widget.loadChatPortrait != null) ...[
            const Divider(),
            _ChatMemorySection(
              loadPortrait: widget.loadChatPortrait!,
              loadQuota: widget.loadChatQuota,
              onClearHistory: widget.onClearChatHistory,
              onClearPortrait: widget.onClearChatPortrait,
            ),
          ],
          if (widget.lockRepo != null) ...[
            const Divider(),
            _DeviceLockSection(lockRepo: widget.lockRepo!),
          ],
          if (widget.ttsTelemetry != null) ...[
            const Divider(),
            _TtsTelemetryTile(telemetry: widget.ttsTelemetry!),
          ],
          const SizedBox(height: 8),
          Text(
            'LachinGo — səyahət zamanı dil öyrənmə köməkçisi',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Settings _withCount(int count) =>
      _settings.copyWith(dailyNotificationCount: count);

  Future<void> _pickUiLanguage(BuildContext context) async {
    final picked = await showDialog<UiLanguage>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(context.s.appLanguage),
        children: [
          for (final lang in UiLanguage.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(lang),
              child: Text(lang.nativeLabel),
            ),
        ],
      ),
    );
    if (picked == null || picked == _settings.uiLanguage) return;
    await _update(_settings.copyWith(uiLanguage: picked));
    widget.onUiLanguageChanged?.call(picked);
  }

  Future<void> _pickHour({
    required int current,
    required ValueChanged<int> onPicked,
  }) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.s.pickHour),
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

/// AI yaddaşı — istifadəçi AI-nin onun haqqında nə bildiyini görür və silə
/// bilir (şəffaflıq/məxfilik). Portret və tarixçə AYRI silinir: istifadəçi
/// söhbəti təmizləmək istəyəndə AI-nin onu tanımasını itirmək istəməyə bilər.
class _ChatMemorySection extends StatefulWidget {
  const _ChatMemorySection({
    required this.loadPortrait,
    this.loadQuota,
    this.onClearHistory,
    this.onClearPortrait,
  });

  final Future<List<String>> Function() loadPortrait;
  final Future<ChatQuota?> Function()? loadQuota;
  final Future<bool> Function()? onClearHistory;
  final Future<bool> Function()? onClearPortrait;

  @override
  State<_ChatMemorySection> createState() => _ChatMemorySectionState();
}

class _ChatMemorySectionState extends State<_ChatMemorySection> {
  List<String>? _facts;
  ChatQuota? _quota;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final factsFuture = widget.loadPortrait();
    final quotaFuture = widget.loadQuota?.call();
    final facts = await factsFuture;
    final quota = quotaFuture != null ? await quotaFuture : null;
    if (mounted) {
      setState(() {
        _facts = facts;
        _quota = quota;
      });
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('İmtina'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _run(Future<bool> Function() action, String okMessage) async {
    setState(() => _busy = true);
    final ok = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? okMessage : 'Alınmadı — internet yoxdur?')),
    );
    if (ok) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final facts = _facts;
    final count = facts?.length ?? 0;
    final s = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.loadQuota != null)
          ListTile(
            leading: const Icon(Icons.hourglass_bottom_outlined),
            title: Text(s.chatQuotaTitle),
            subtitle: _quota == null
                ? const Text('Yüklənir…')
                : Text(s.chatQuotaSummary(_quota!.used, _quota!.limit)),
            trailing: _quota == null
                ? null
                : Text(
                    s.chatQuotaRemaining(_quota!.remaining),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: _quota!.isLow
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.outline,
                        ),
                  ),
          ),
        ListTile(
          title: const Text('AI yaddaşı'),
          subtitle: Text(facts == null
              ? 'Yüklənir…'
              : count == 0
                  ? 'AI hələ sənin haqqında heç nə yadda saxlamayıb'
                  : 'AI sənin haqqında $count şey bilir'),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Yenilə',
                  onPressed: _reload,
                ),
        ),
        if (facts != null && facts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final fact in facts)
                  Chip(
                    label: Text(fact, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        if (widget.onClearHistory != null)
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Söhbəti təmizlə'),
            subtitle: const Text('Yazışma silinir, AI səni yenə tanıyır'),
            onTap: _busy
                ? null
                : () async {
                    if (await _confirm('Söhbəti təmizlə?',
                        'Bütün yazışma silinəcək. AI-nin sənin haqqında '
                        'bildikləri qalacaq.')) {
                      await _run(widget.onClearHistory!, 'Söhbət təmizləndi');
                    }
                  },
          ),
        if (widget.onClearPortrait != null)
          ListTile(
            leading: const Icon(Icons.person_off_outlined),
            title: const Text('AI yaddaşını sıfırla'),
            subtitle: const Text('AI səni sıfırdan tanımağa başlayır'),
            onTap: _busy
                ? null
                : () async {
                    if (await _confirm('AI yaddaşını sıfırla?',
                        'AI-nin sənin haqqında bildikləri silinəcək — '
                        'səni yenidən tanımağa başlayacaq.')) {
                      await _run(
                          widget.onClearPortrait!, 'AI yaddaşı sıfırlandı');
                    }
                  },
          ),
      ],
    );
  }
}

/// PIN və biometrik kilid idarəsi.
class _DeviceLockSection extends StatefulWidget {
  const _DeviceLockSection({required this.lockRepo});

  final DeviceLockRepository lockRepo;

  @override
  State<_DeviceLockSection> createState() => _DeviceLockSectionState();
}

class _DeviceLockSectionState extends State<_DeviceLockSection> {
  bool? _enabled;
  bool? _biometric;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final enabled = await widget.lockRepo.isEnabled();
    final biometric = await widget.lockRepo.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _biometric = biometric;
      });
    }
  }

  Future<void> _setPin() async {
    final ok = await showPinSetupDialog(context, widget.lockRepo);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s.pinSetSuccess)),
      );
      await _reload();
    }
  }

  Future<void> _disableLock() async {
    setState(() => _busy = true);
    await widget.lockRepo.clear();
    if (!mounted) return;
    setState(() => _busy = false);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final enabled = _enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(s.deviceLockTitle),
          subtitle: Text(s.deviceLockSubtitle),
        ),
        if (enabled == null)
          const ListTile(
            title: Text('Yüklənir…'),
          )
        else if (!enabled) ...[
          ListTile(
            title: Text(s.setPinTitle),
            trailing: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _busy ? null : _setPin,
          ),
        ] else ...[
          ListTile(
            title: Text(s.changePin),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : _setPin,
          ),
          SwitchListTile(
            title: Text(s.biometricUnlock),
            value: _biometric ?? false,
            onChanged: _busy
                ? null
                : (v) async {
                    await widget.lockRepo.setBiometricEnabled(v);
                    await _reload();
                  },
          ),
          ListTile(
            title: Text(s.disableDeviceLock),
            leading: const Icon(Icons.lock_open_outlined),
            onTap: _busy ? null : _disableLock,
          ),
        ],
      ],
    );
  }
}

/// Offline səsli kitablar — vəziyyət + "Endir"/"Sil" düymələri.
///
/// Tətbiqin əsas fəlsəfəsi: bir dəfə (Wi-Fi ilə) endirdikdən sonra
/// internet olmasa belə dinləmək mümkün olsun (bax dildostu/CLAUDE.md).
/// `ListenableBuilder` ilə `AudiobookDownloader`-i izləyir ki, fon endirməsi
/// gedərkən faiz canlı yenilənsin — amma bu `ListTile` HƏMİŞƏ ağacdadır
/// (`SettingsScreen.build`-də şərt yalnız konstruktor sahələrinə görədir,
/// runtime-da dəyişmir), ona görə `home_tab.dart`-dakı "dinamik widget
/// əlavəsi" bug-ı sinfindən kənardır.
class _OfflineAudiobooksSection extends StatefulWidget {
  const _OfflineAudiobooksSection({
    required this.downloader,
    required this.loadLibrary,
    required this.onDownload,
  });

  final AudiobookDownloader downloader;
  final Future<List<Audiobook>> Function() loadLibrary;
  final Future<void> Function(List<Audiobook> books) onDownload;

  @override
  State<_OfflineAudiobooksSection> createState() =>
      _OfflineAudiobooksSectionState();
}

class _OfflineAudiobooksSectionState extends State<_OfflineAudiobooksSection> {
  List<Audiobook>? _books;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final books = await widget.loadLibrary();
      if (mounted) setState(() => _books = books);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';

  Future<void> _clear() async {
    await widget.downloader.clearDownloads();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final books = _books;
    return ListenableBuilder(
      listenable: widget.downloader,
      builder: (context, _) {
        final downloader = widget.downloader;
        String subtitle;
        Widget trailing;
        if (books == null) {
          subtitle = _error != null
              ? 'Kitabxana yoxlanmadı: $_error'
              : 'Yoxlanılır…';
          trailing = const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          );
        } else if (downloader.downloading) {
          final percent = (downloader.progress * 100).toStringAsFixed(0);
          subtitle = 'Yüklənir… $percent%';
          trailing = SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              value: downloader.progress > 0 ? downloader.progress : null,
            ),
          );
        } else {
          final pending = downloader.pendingBytes(books);
          final downloaded = downloader.downloadedBytes(books);
          if (pending == 0 && downloaded > 0) {
            subtitle = 'Hamısı endirilib (${_mb(downloaded)}) — offline hazır';
            trailing = IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Offline kitabları sil',
              onPressed: _clear,
            );
          } else if (pending > 0) {
            subtitle = downloaded > 0
                ? '${_mb(downloaded)} endirilib, ${_mb(pending)} qalır'
                : '${_mb(pending)} endirilə bilər (internetsiz dinləmək üçün)';
            trailing = FilledButton.tonal(
              onPressed: () => widget.onDownload(books),
              child: const Text('Endir'),
            );
          } else {
            subtitle = 'Hələ kitab yoxdur';
            trailing = const SizedBox.shrink();
          }
        }
        return ListTile(
          title: const Text('Offline səsli kitablar'),
          subtitle: Text(subtitle),
          trailing: trailing,
        );
      },
    );
  }
}

/// Faza 0 baseline rəqəmini göstərir — inkişaf/diaqnostika üçün, adi
/// istifadəçini narahat etməyən sadə mətn.
class _TtsTelemetryTile extends StatelessWidget {
  const _TtsTelemetryTile({required this.telemetry});

  final TtsTelemetry telemetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = DateTime.now().difference(telemetry.since).inDays;
    final percent = (telemetry.failureRate * 100).toStringAsFixed(1);
    return ListTile(
      title: const Text('Səs statistikası (daxili)'),
      subtitle: Text(
        '$days gündür yığılır — ${telemetry.attempts} cəhd, '
        '${telemetry.failures} uğursuz ($percent%), '
        '${telemetry.noVoiceDetections} dəfə EN səs tapılmadı',
      ),
      subtitleTextStyle: theme.textTheme.bodySmall
          ?.copyWith(color: theme.colorScheme.outline),
    );
  }
}
