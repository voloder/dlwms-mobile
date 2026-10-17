import 'package:dlwms_mobile/models/uspjeh.dart';
import 'package:dlwms_mobile/provider/uspjeh_provider.dart';
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

    return DefaultTabController(
      length: 2,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(child: _StudyInfoCard(data: data)),
          SliverToBoxAdapter(
            child: TabBar(
              tabs: [
                Tab(text: 'Položeni (${data.passedCount})'),
                Tab(text: 'Nepoloženi (${data.pendingCount})'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: provider.refresh,
              child: data.passed.isEmpty
                  ? const EmptyState(text: 'Nema položenih ispita.')
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        for (final group in data.passed) ...[
                          _GroupHeader(group.title),
                          for (final exam in group.exams) _PassedTile(exam),
                        ],
                      ],
                    ),
            ),
            RefreshIndicator(
              onRefresh: provider.refresh,
              child: data.pending.isEmpty
                  ? const EmptyState(text: 'Nema nepoloženih ispita.')
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        for (final group in data.pending) ...[
                          _GroupHeader(group.title),
                          for (final exam in group.exams) _PendingTile(exam),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyInfoCard extends StatelessWidget {
  const _StudyInfoCard({required this.data});

  final UspjehPageData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = data.info;

    Widget fact(String label, String value) => SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              Text(value.isEmpty ? '–' : value,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prosječna ocjena',
                          style: theme.textTheme.bodyMedium),
                      Text(
                        info.averageGrade.isEmpty ? '–' : info.averageGrade,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Chip(label: Text(info.status.isEmpty ? '–' : info.status)),
                    Text('${data.passedCount} položeno',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                fact('Godina studija', info.yearOfStudy),
                fact('Godina upisa', info.enrollmentYear),
                fact('Upisani semestar',
                    '${info.enrolledSemester} (${info.enrolledSchoolYear})'),
                fact('Ovjereni semestar',
                    '${info.verifiedSemester} (${info.verifiedSchoolYear})'),
                fact('Način studiranja', info.studyMode),
                fact('Obnavlja godinu', info.repeatingYear),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
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
    final subtitle = [
      if (exam.date != null) DateFormat('dd.MM.yyyy').format(exam.date!),
      if (exam.gradeDescription.isNotEmpty) exam.gradeDescription,
    ].join(' · ');

    return ListTile(
      title: Text(exam.subject),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: Text(
          exam.grade?.toString() ?? '–',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile(this.exam);

  final PendingExam exam;

  @override
  Widget build(BuildContext context) {
    final details = [
      exam.requirementMet ? 'Uslov ispunjen' : 'Uslov nije ispunjen',
      if (exam.requirementDate.isNotEmpty) exam.requirementDate,
      if (exam.attempts != null) 'izlazaka: ${exam.attempts}',
    ].join(' · ');

    return ListTile(
      leading: Icon(
        exam.requirementMet ? Icons.check_circle : Icons.radio_button_unchecked,
        color: exam.requirementMet ? Colors.green : null,
      ),
      title: Text(exam.subject),
      subtitle: Text(details),
    );
  }
}
