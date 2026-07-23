import 'package:flutter/material.dart';

/// Arxa fon məkan icazəsini izah edib istəyən ekran. Plugin çağırışları inject
/// olunur (main.dart-da LocationService/RoutineSampler-ə bağlanır; testdə fake).
class RoutinePermissionScreen extends StatefulWidget {
  const RoutinePermissionScreen({
    super.key,
    required this.requestAlways,
    required this.openSettings,
    required this.onGranted,
    this.onSampleNow,
  });

  /// "Həmişə" icazəsini istəyir; verildisə `true`.
  final Future<bool> Function() requestAlways;

  /// Sistem tənzimləmələrini açır (Android 11+ əl ilə "Həmişə icazə ver").
  final Future<void> Function() openSettings;

  /// İcazə verildikdə çağırılır (main.dart RoutineSampler-i qeyd edir).
  final VoidCallback onGranted;

  /// "İndi yoxla" — dərhal ön-plan nümunəsi götürüb nəticə mətnini qaytarır.
  final Future<String> Function()? onSampleNow;

  @override
  State<RoutinePermissionScreen> createState() =>
      _RoutinePermissionScreenState();
}

class _RoutinePermissionScreenState extends State<RoutinePermissionScreen> {
  bool _busy = false;
  bool _needsSettings = false;
  bool _granted = false;
  bool _sampling = false;
  String? _sampleResult;

  Future<void> _request() async {
    setState(() => _busy = true);
    final ok = await widget.requestAlways();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _granted = ok;
      _needsSettings = !ok;
    });
    if (ok) widget.onGranted();
  }

  Future<void> _sampleNow() async {
    setState(() => _sampling = true);
    final msg = await widget.onSampleNow!();
    if (!mounted) return;
    setState(() {
      _sampling = false;
      _sampleResult = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rutin öyrənmə')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.explore_outlined, size: 64),
            const SizedBox(height: 16),
            Text('AI gündəlik rutinini öyrənsin',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text(
              'İcazə versən, DilDostu arxa planda tez-tez getdiyin yerləri '
              '(kafe, market, park...) öyrənəcək və oraya çatanda sənə uyğun '
              'sözləri özü təklif edəcək — proqram bağlı olsa belə.\n\n'
              'Məkan məlumatın anonimdir (adın saxlanmır).',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_granted)
              Card(
                color: theme.colorScheme.primaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('✅ İcazə verildi. AI artıq rutinini öyrənir.',
                      textAlign: TextAlign.center),
                ),
              )
            else ...[
              FilledButton.icon(
                onPressed: _busy ? null : _request,
                icon: const Icon(Icons.check),
                label: const Text('İcazə ver'),
              ),
              if (_needsSettings) ...[
                const SizedBox(height: 12),
                const Text(
                  '"Həmişə icazə ver" seçimi üçün Ayarlara keçib məkan '
                  'icazəsini "Həmişə" et.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: widget.openSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Ayarları aç'),
                ),
              ],
            ],
            if (widget.onSampleNow != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              Text('Sınaq',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _sampling ? null : _sampleNow,
                icon: _sampling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: const Text('İndi olduğum yeri yoxla'),
              ),
              if (_sampleResult != null) ...[
                const SizedBox(height: 12),
                Text(_sampleResult!, textAlign: TextAlign.center),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
