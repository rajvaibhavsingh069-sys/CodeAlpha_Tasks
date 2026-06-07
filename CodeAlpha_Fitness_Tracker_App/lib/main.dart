import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const FitnessTrackerApp());
}

class FitnessTrackerApp extends StatelessWidget {
  const FitnessTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FitTrack',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF159A8C),
          primary: const Color(0xFF159A8C),
          secondary: const Color(0xFFF56C58),
          tertiary: const Color(0xFF3D6FB6),
          surface: const Color(0xFFF8FAF8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF6F8F7),
          foregroundColor: Color(0xFF182522),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const FitnessHomePage(),
    );
  }
}

class FitnessHomePage extends StatefulWidget {
  const FitnessHomePage({super.key});

  @override
  State<FitnessHomePage> createState() => _FitnessHomePageState();
}

class _FitnessHomePageState extends State<FitnessHomePage> {
  final ActivityStore _store = ActivityStore();
  var _entries = <ActivityEntry>[];
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await _store.loadEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  Future<void> _addEntry(ActivityEntry entry) async {
    final updated = [..._entries, entry]
      ..sort((a, b) => b.date.compareTo(a.date));
    await _store.saveEntries(updated);
    setState(() => _entries = updated);
  }

  Future<void> _deleteEntry(ActivityEntry entry) async {
    final updated = _entries.where((item) => item.id != entry.id).toList();
    await _store.saveEntries(updated);
    setState(() => _entries = updated);
  }

  void _openLogSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ActivityEntrySheet(onSave: _addEntry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayEntries = _entries.where(
      (entry) => isSameDay(entry.date, today),
    );
    final todaySummary = ActivitySummary.fromEntries(todayEntries);
    final weekEntries = entriesForCurrentWeek(_entries, today);
    final weekSummary = ActivitySummary.fromEntries(weekEntries);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FitTrack', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              'Daily activity journal',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add activity',
            onPressed: _openLogSheet,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxContentWidth = constraints.maxWidth < 700
                    ? math.min(354.0, constraints.maxWidth)
                    : 880.0;

                return RefreshIndicator(
                  onRefresh: _loadEntries,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
                    children: [
                      Align(
                        alignment: constraints.maxWidth < 700
                            ? Alignment.centerLeft
                            : Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DashboardHeader(summary: todaySummary),
                              const SizedBox(height: 18),
                              ProgressSection(summary: todaySummary),
                              const SizedBox(height: 18),
                              WeeklyChart(
                                entries: weekEntries,
                                anchorDate: today,
                              ),
                              const SizedBox(height: 18),
                              WeeklySummary(summary: weekSummary),
                              const SizedBox(height: 18),
                              RecentActivityList(
                                entries: _entries.take(8).toList(),
                                onDelete: _deleteEntry,
                                onAdd: _openLogSheet,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openLogSheet,
        icon: const Icon(Icons.add),
        label: const Text('Log'),
      ),
      floatingActionButtonLocation: MediaQuery.of(context).size.width < 700
          ? FloatingActionButtonLocation.startFloat
          : FloatingActionButtonLocation.endFloat,
    );
  }
}

class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.minutes,
    required this.calories,
    required this.steps,
    required this.notes,
  });

  final String id;
  final DateTime date;
  final String type;
  final int minutes;
  final int calories;
  final int steps;
  final String notes;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'type': type,
      'minutes': minutes,
      'calories': calories,
      'steps': steps,
      'notes': notes,
    };
  }

  factory ActivityEntry.fromJson(Map<String, Object?> json) {
    return ActivityEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      type: json['type'] as String,
      minutes: (json['minutes'] as num).round(),
      calories: (json['calories'] as num).round(),
      steps: (json['steps'] as num).round(),
      notes: (json['notes'] as String?) ?? '',
    );
  }
}

class ActivityStore {
  static const _storageKey = 'fitness_entries_v1';

  Future<List<ActivityEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedEntries = prefs.getStringList(_storageKey) ?? <String>[];
    final entries =
        encodedEntries
            .map((entry) => ActivityEntry.fromJson(jsonDecode(entry)))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Future<void> saveEntries(List<ActivityEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedEntries = entries
        .map((entry) => jsonEncode(entry.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_storageKey, encodedEntries);
  }
}

class ActivitySummary {
  const ActivitySummary({
    required this.steps,
    required this.calories,
    required this.minutes,
    required this.workouts,
  });

  final int steps;
  final int calories;
  final int minutes;
  final int workouts;

  factory ActivitySummary.fromEntries(Iterable<ActivityEntry> entries) {
    var steps = 0;
    var calories = 0;
    var minutes = 0;
    var workouts = 0;

    for (final entry in entries) {
      steps += entry.steps;
      calories += entry.calories;
      minutes += entry.minutes;
      if (entry.minutes > 0 || entry.calories > 0) workouts++;
    }

    return ActivitySummary(
      steps: steps,
      calories: calories,
      minutes: minutes,
      workouts: workouts,
    );
  }
}

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({required this.summary, super.key});

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: const Color(0xFF182522),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          readableDate(DateTime.now()),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF5E706B)),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                StatTile(
                  width: compact ? (constraints.maxWidth - 12) / 2 : 180,
                  icon: Icons.directions_walk,
                  color: const Color(0xFF159A8C),
                  label: 'Steps',
                  value: formatNumber(summary.steps),
                ),
                StatTile(
                  width: compact ? (constraints.maxWidth - 12) / 2 : 180,
                  icon: Icons.local_fire_department_outlined,
                  color: const Color(0xFFF56C58),
                  label: 'Calories',
                  value: '${formatNumber(summary.calories)} kcal',
                ),
                StatTile(
                  width: compact ? constraints.maxWidth : 180,
                  icon: Icons.timer_outlined,
                  color: const Color(0xFF3D6FB6),
                  label: 'Active time',
                  value: '${summary.minutes} min',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    required this.width,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    super.key,
  });

  final double width;
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundColor: color,
                child: Icon(icon, size: 21),
              ),
              const SizedBox(height: 14),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Color(0xFF667671))),
            ],
          ),
        ),
      ),
    );
  }
}

class ProgressSection extends StatelessWidget {
  const ProgressSection({required this.summary, super.key});

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'Daily goals',
      trailing: const Icon(Icons.flag_outlined, color: Color(0xFF159A8C)),
      child: Column(
        children: [
          GoalProgressRow(
            label: 'Steps',
            value: summary.steps,
            target: 10000,
            suffix: '',
            color: const Color(0xFF159A8C),
          ),
          const SizedBox(height: 16),
          GoalProgressRow(
            label: 'Calories',
            value: summary.calories,
            target: 600,
            suffix: 'kcal',
            color: const Color(0xFFF56C58),
          ),
          const SizedBox(height: 16),
          GoalProgressRow(
            label: 'Active minutes',
            value: summary.minutes,
            target: 60,
            suffix: 'min',
            color: const Color(0xFF3D6FB6),
          ),
        ],
      ),
    );
  }
}

class GoalProgressRow extends StatelessWidget {
  const GoalProgressRow({
    required this.label,
    required this.value,
    required this.target,
    required this.suffix,
    required this.color,
    super.key,
  });

  final String label;
  final int value;
  final int target;
  final String suffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = (value / target).clamp(0.0, 1.0);
    final valueText = suffix.isEmpty
        ? '${formatNumber(value)} / ${formatNumber(target)}'
        : '${formatNumber(value)} / ${formatNumber(target)} $suffix';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(valueText, style: const TextStyle(color: Color(0xFF667671))),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: progress,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class WeeklyChart extends StatelessWidget {
  const WeeklyChart({
    required this.entries,
    required this.anchorDate,
    super.key,
  });

  final List<ActivityEntry> entries;
  final DateTime anchorDate;

  @override
  Widget build(BuildContext context) {
    final start = weekStart(anchorDate);
    final days = List.generate(7, (index) => start.add(Duration(days: index)));
    final summaries = days
        .map(
          (day) => ActivitySummary.fromEntries(
            entries.where((entry) => isSameDay(entry.date, day)),
          ),
        )
        .toList();
    final maxMinutes = math.max(
      60,
      summaries.map((summary) => summary.minutes).fold<int>(0, math.max),
    );

    return SectionPanel(
      title: 'Weekly active minutes',
      trailing: Text(
        '${totalMinutes(summaries)} min',
        style: const TextStyle(
          color: Color(0xFF159A8C),
          fontWeight: FontWeight.w800,
        ),
      ),
      child: SizedBox(
        height: 190,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < days.length; index++)
              Expanded(
                child: _DayBar(
                  date: days[index],
                  minutes: summaries[index].minutes,
                  maxMinutes: maxMinutes,
                  isToday: isSameDay(days[index], anchorDate),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.date,
    required this.minutes,
    required this.maxMinutes,
    required this.isToday,
  });

  final DateTime date;
  final int minutes;
  final int maxMinutes;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final height = 24 + (minutes / maxMinutes * 104);
    final color = isToday ? const Color(0xFFF56C58) : const Color(0xFF159A8C);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            minutes == 0 ? '' : '$minutes',
            style: const TextStyle(fontSize: 12, color: Color(0xFF667671)),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: minutes == 0 ? 0.16 : 0.82),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            weekdayLabel(date),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
              color: isToday ? color : const Color(0xFF667671),
            ),
          ),
        ],
      ),
    );
  }
}

class WeeklySummary extends StatelessWidget {
  const WeeklySummary({required this.summary, super.key});

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'This week',
      trailing: const Icon(Icons.insights_outlined, color: Color(0xFF3D6FB6)),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          MiniMetric(
            icon: Icons.fitness_center,
            label: 'Workouts',
            value: '${summary.workouts}',
          ),
          MiniMetric(
            icon: Icons.directions_walk,
            label: 'Steps',
            value: formatNumber(summary.steps),
          ),
          MiniMetric(
            icon: Icons.local_fire_department_outlined,
            label: 'Calories',
            value: '${formatNumber(summary.calories)} kcal',
          ),
        ],
      ),
    );
  }
}

class MiniMetric extends StatelessWidget {
  const MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF159A8C), size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667671),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecentActivityList extends StatelessWidget {
  const RecentActivityList({
    required this.entries,
    required this.onDelete,
    required this.onAdd,
    super.key,
  });

  final List<ActivityEntry> entries;
  final ValueChanged<ActivityEntry> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: 'Recent logs',
      trailing: IconButton(
        tooltip: 'Add activity',
        onPressed: onAdd,
        icon: const Icon(Icons.add),
      ),
      child: entries.isEmpty
          ? EmptyActivityState(onAdd: onAdd)
          : Column(
              children: [
                for (final entry in entries)
                  ActivityListTile(entry: entry, onDelete: onDelete),
              ],
            ),
    );
  }
}

class EmptyActivityState extends StatelessWidget {
  const EmptyActivityState({required this.onAdd, super.key});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          const Icon(
            Icons.edit_calendar_outlined,
            size: 42,
            color: Color(0xFF159A8C),
          ),
          const SizedBox(height: 10),
          Text(
            'No fitness data yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Log steps, workout time, exercise type, and calories manually.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF667671)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add first log'),
          ),
        ],
      ),
    );
  }
}

class ActivityListTile extends StatelessWidget {
  const ActivityListTile({
    required this.entry,
    required this.onDelete,
    super.key,
  });

  final ActivityEntry entry;
  final ValueChanged<ActivityEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4EBE8)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF159A8C).withValues(alpha: 0.12),
            foregroundColor: const Color(0xFF159A8C),
            child: Icon(iconForType(entry.type)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.type,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${shortDate(entry.date)}  |  ${entry.minutes} min  |  ${formatNumber(entry.steps)} steps  |  ${entry.calories} kcal',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667671),
                  ),
                ),
                if (entry.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.notes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete log',
            onPressed: () => onDelete(entry),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class ActivityEntrySheet extends StatefulWidget {
  const ActivityEntrySheet({required this.onSave, super.key});

  final ValueChanged<ActivityEntry> onSave;

  @override
  State<ActivityEntrySheet> createState() => _ActivityEntrySheetState();
}

class _ActivityEntrySheetState extends State<ActivityEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _minutesController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _stepsController = TextEditingController();
  final _notesController = TextEditingController();
  var _date = DateTime.now();
  var _type = activityTypes.first;

  @override
  void dispose() {
    _minutesController.dispose();
    _caloriesController.dispose();
    _stepsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected != null) {
      setState(() => _date = selected);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final minutes = int.tryParse(_minutesController.text.trim()) ?? 0;
    final calories = int.tryParse(_caloriesController.text.trim()) ?? 0;
    final steps = int.tryParse(_stepsController.text.trim()) ?? 0;

    if (minutes + calories + steps == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one activity number.')),
      );
      return;
    }

    widget.onSave(
      ActivityEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: _date,
        type: _type,
        minutes: minutes,
        calories: calories,
        steps: steps,
        notes: _notesController.text.trim(),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Log activity',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Exercise type'),
                items: [
                  for (final type in activityTypes)
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(shortDate(_date)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: NumberField(
                      controller: _minutesController,
                      label: 'Minutes',
                      icon: Icons.timer_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NumberField(
                      controller: _caloriesController,
                      label: 'Calories',
                      icon: Icons.local_fire_department_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              NumberField(
                controller: _stepsController,
                label: 'Steps',
                icon: Icons.directions_walk,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Save log'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NumberField extends StatelessWidget {
  const NumberField({
    required this.controller,
    required this.label,
    required this.icon,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return null;
        final parsed = int.tryParse(text);
        if (parsed == null || parsed < 0) return 'Use 0 or more';
        return null;
      },
    );
  }
}

class SectionPanel extends StatelessWidget {
  const SectionPanel({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

const activityTypes = [
  'Walking',
  'Running',
  'Cycling',
  'Strength',
  'Yoga',
  'Swimming',
  'Other',
];

IconData iconForType(String type) {
  return switch (type) {
    'Running' => Icons.directions_run,
    'Cycling' => Icons.directions_bike,
    'Strength' => Icons.fitness_center,
    'Yoga' => Icons.self_improvement,
    'Swimming' => Icons.pool,
    _ => Icons.directions_walk,
  };
}

List<ActivityEntry> entriesForCurrentWeek(
  List<ActivityEntry> entries,
  DateTime anchor,
) {
  final start = weekStart(anchor);
  final end = start.add(const Duration(days: 7));
  return entries
      .where(
        (entry) =>
            !entry.dateOnly.isBefore(start) && entry.dateOnly.isBefore(end),
      )
      .toList();
}

DateTime weekStart(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

extension ActivityEntryDate on ActivityEntry {
  DateTime get dateOnly => DateTime(date.year, date.month, date.day);
}

int totalMinutes(List<ActivitySummary> summaries) {
  return summaries.fold(0, (total, summary) => total + summary.minutes);
}

String formatNumber(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    final remaining = text.length - index;
    buffer.write(text[index]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

String readableDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdayFullLabel(date)}, ${months[date.month - 1]} ${date.day}';
}

String shortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String weekdayLabel(DateTime date) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[date.weekday - 1];
}

String weekdayFullLabel(DateTime date) {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return days[date.weekday - 1];
}
