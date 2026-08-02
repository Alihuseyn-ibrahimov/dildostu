import 'package:flutter/material.dart';

import '../data/settings_repository.dart';
import '../models/settings.dart';

const _minCount = 5;
const _maxCount = 10;

/// Oyanma/yatma vaxtı və gündəlik bildiriş sayını tənzimləmək üçün ekran.
/// Dəyişikliklər dərhal SettingsRepository-ə saxlanır; növbəti app açılışında
/// (main.dart bootstrap) yeni bildiriş cədvəli qurulur.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository, this.buildLabel});

  final SettingsRepository repository;

  /// Quraşdırılmış tam versiya (məs. "1.0.0+7") — auto-update diaqnostikası
  /// üçün. Android Ayarlar yalnız versionName-i (həmişə "1.0.0") göstərdiyi
  /// üçün buradan görmək lazımdır. Null-dursa göstərilmir.
  final String? buildLabel;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Settings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.repository.current;
  }

  Future<void> _update(Settings next) async {
    setState(() => _settings = next);
    await widget.repository.save(next);
  }

  @override
  Widget build(BuildContext context) {
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
          if (widget.buildLabel != null) ...[
            const Divider(),
            ListTile(
              title: const Text('Buraxılış'),
              trailing: Text(widget.buildLabel!),
            ),
          ],
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
