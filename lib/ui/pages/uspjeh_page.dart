import 'package:dlwms_mobile/models/uspjeh.dart';
import 'package:dlwms_mobile/provider/uspjeh_provider.dart';
import 'package:dlwms_mobile/theme/app_theme.dart';
import 'package:dlwms_mobile/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class UspjehPage extends StatefulWidget {
  const UspjehPage({super.key});

  @override
  State<UspjehPage> createState() => _UspjehPageState();
}

class _UspjehPageState extends State<UspjehPage>
    with AutomaticKeepAliveClientMixin {
  bool _showPassed = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UspjehProvider>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<UspjehProvider>();
    final data = provider.data;

    if (provider.state == UspjehProviderState.loading || data == null) {
      if (provider.state == UspjehProviderState.error) {
        return ErrorState(
          message: provider.errorMessage ?? 'Uspjeh nije moguće učitati.',
          onRetry: provider.fetch,
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _OverviewCard(data: data),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text('Položeni · ${data.passedCount}'),
                ),
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.pending_outlined),
                  label: Text('Nepoloženi · ${data.pendingCount}'),
                ),
              ],
              selected: {_showPassed},
              onSelectionChanged: (value) =>
                  setState(() => _showPassed = value.first),
            ),
          ),
          if (_showPassed) ...[
            if (data.passed.isEmpty)
              const _Empty(text: 'Nema položenih ispita.')
            else
              for (final group in data.passed)
                _GroupCard(
                  title: group.title,
                  trailing: _groupAverage(group),
                  children: [for (final exam in group.exams) _PassedTile(exam)],
                ),
          ] else ...[
            if (data.pending.isEmpty)
              const _Empty(text: 'Sve je položeno. Bravo!')
            else
              for (final group in data.pending)
                _GroupCard(
                  title: group.title,
                  trailing: '${group.exams.length} predmeta',
                  children: [
                    for (final exam in group.exams) _PendingTile(exam)
                  ],
                ),
          ],
        ],
      ),
    );
  }

  static String? _groupAverage(ExamGroup<PassedExam> group) {
    final grades = group.exams.map((e) => e.grade).whereType<int>().toList();
    if (grades.isEmpty) return null;
    final avg = grades.reduce((a, b) => a + b) / grades.length;
    return 'prosjek ${avg.toStringAsFixed(2)}';
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.data});

  final UspjehPageData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = data.info;
    final onCard = scheme.onPrimaryContainer;

    Widget stat(String value, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value.isEmpty ? '–' : value,
                  style: theme.textTheme.titleLarge?.copyWith(color: onCard)),
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: onCard.withValues(alpha: 0.75))),
            ],
          ),
        );

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prosječna ocjena',
                          style: theme.textTheme.titleSmall?.copyWith(
                              color: onCard.withValues(alpha: 0.8))),
                      Text(
                        info.averageGrade.isEmpty ? '–' : info.averageGrade,
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: onCard,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (info.status.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      info.status,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.onPrimary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                stat('${data.passedCount}', 'položeno'),
                stat('${data.pendingCount}', 'preostalo'),
                stat(info.yearOfStudy, 'godina studija'),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: onCard.withValues(alpha: 0.15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _Fact(Icons.event_outlined, 'Upisan',
                    '${info.enrolledSemester}. sem · ${info.enrolledSchoolYear}',
                    onCard),
                _Fact(Icons.verified_outlined, 'Ovjeren',
                    '${info.verifiedSemester}. sem · ${info.verifiedSchoolYear}',
                    onCard),
                _Fact(Icons.person_outline, 'Način', info.studyMode, onCard),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label, this.value, this.color);

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color.withValues(alpha: 0.75)),
        const SizedBox(width: 4),
        Text('$label: ',
            style: style?.copyWith(color: color.withValues(alpha: 0.75))),
        Text(value,
            style: style?.copyWith(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final String? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title,
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            trailing: trailing == null
                ? null
                : Text(trailing!,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
          ),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(indent: 68),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PassedTile extends StatelessWidget {
  const _PassedTile(this.exam);

  final PassedExam exam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final grade = exam.grade;

    // Higher grades get the stronger accent.
    final (Color bg, Color fg) = switch (grade) {
      10 => (scheme.primary, scheme.onPrimary),
      9 => (scheme.primaryContainer, scheme.onPrimaryContainer),
      8 || 7 => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };

    final subtitle = [
      if (exam.date != null) DateFormat('dd.MM.yyyy').format(exam.date!),
      if (exam.gradeDescription.isNotEmpty) exam.gradeDescription,
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(14, 4, 16, 4),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.small + 2),
        ),
        child: Text(
          grade?.toString() ?? '–',
          style: theme.textTheme.titleMedium
              ?.copyWith(color: fg, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(exam.subject),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile(this.exam);

  final PendingExam exam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = StatusColors.of(context);
    final color = exam.requirementMet ? status.good : theme.colorScheme.outline;

    final details = [
      exam.requirementMet ? 'Uslov ispunjen' : 'Uslov nije ispunjen',
      if (exam.requirementDate.isNotEmpty) exam.requirementDate,
      if (exam.attempts != null) 'izlazaka: ${exam.attempts}',
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(14, 4, 16, 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.small + 2),
        ),
        child: Icon(
          exam.requirementMet
              ? Icons.task_alt_rounded
              : Icons.hourglass_empty_rounded,
          size: 20,
          color: color,
        ),
      ),
      title: Text(exam.subject),
      subtitle: Text(details),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: EmptyState(text: text, icon: Icons.emoji_events_outlined),
    );
  }
}
