import 'package:flutter/material.dart';

import '../models/user_profile.dart';

/// İlk açılışda istifadəçi profilini toplayır (canlı AI-ni fərdiləşdirmək üçün).
/// Tamamlananda `onComplete` düzgün UserProfile ilə çağırılır.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final ValueChanged<UserProfile> onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  LearningPurpose _purpose = LearningPurpose.travel;
  ProficiencyLevel _level = ProficiencyLevel.beginner;
  TargetLanguage _targetLang = TargetLanguage.english;
  int _wakeHour = 8;
  int _sleepHour = 23;
  final _interestsController = TextEditingController();

  @override
  void dispose() {
    _interestsController.dispose();
    super.dispose();
  }

  void _submit() {
    final interests = _interestsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    widget.onComplete(UserProfile(
      wakeHour: _wakeHour,
      sleepHour: _sleepHour,
      purpose: _purpose,
      level: _level,
      interests: interests,
      targetLang: _targetLang,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xoş gəldin! 👋')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('AI köməkçini sənə uyğunlaşdıraq',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          const Text('Hansı dili öyrənmək istəyirsən?'),
          const SizedBox(height: 8),
          SegmentedButton<TargetLanguage>(
            segments: [
              for (final lang in TargetLanguage.values)
                ButtonSegment(value: lang, label: Text(lang.labelAz)),
            ],
            selected: {_targetLang},
            onSelectionChanged: (s) => setState(() => _targetLang = s.first),
          ),
          const SizedBox(height: 20),
          const Text('Niyə İngilis dili öyrənirsən?'),
          const SizedBox(height: 8),
          SegmentedButton<LearningPurpose>(
            segments: const [
              ButtonSegment(value: LearningPurpose.travel, label: Text('Səyahət')),
              ButtonSegment(value: LearningPurpose.work, label: Text('İş')),
              ButtonSegment(value: LearningPurpose.general, label: Text('Ümumi')),
            ],
            selected: {_purpose},
            onSelectionChanged: (s) => setState(() => _purpose = s.first),
          ),
          const SizedBox(height: 20),
          const Text('Çətinlik səviyyəsi?'),
          const SizedBox(height: 8),
          SegmentedButton<ProficiencyLevel>(
            segments: [
              for (final level in ProficiencyLevel.values)
                ButtonSegment(value: level, label: Text(level.labelAz)),
            ],
            selected: {_level},
            onSelectionChanged: (s) => setState(() => _level = s.first),
          ),
          const SizedBox(height: 6),
          Text(
            _level.hintAz,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _HourPicker(
                  label: 'Oyanma',
                  value: _wakeHour,
                  onChanged: (h) => setState(() => _wakeHour = h),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HourPicker(
                  label: 'Yatma',
                  value: _sleepHour,
                  onChanged: (h) => setState(() => _sleepHour = h),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _interestsController,
            decoration: const InputDecoration(
              labelText: 'Maraqların (vergüllə)',
              hintText: 'yemək, idman, texnologiya',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _submit,
            child: const Text('Başla'),
          ),
        ],
      ),
    );
  }
}

class _HourPicker extends StatelessWidget {
  const _HourPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: DropdownButton<int>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text('$h:00'))],
        onChanged: (h) => h == null ? null : onChanged(h),
      ),
    );
  }
}
