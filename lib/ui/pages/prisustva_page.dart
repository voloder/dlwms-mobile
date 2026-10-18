import 'package:dlwms_mobile/models/prisustvo.dart';
import 'package:dlwms_mobile/provider/prisustvo_provider.dart';
import 'package:dlwms_mobile/theme/app_theme.dart';
import 'package:dlwms_mobile/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PrisustvaPage extends StatefulWidget {
  const PrisustvaPage({super.key});

  @override
  State<PrisustvaPage> createState() => _PrisustvaPageState();
}

class _PrisustvaPageState extends State<PrisustvaPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrisustvoProvider>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<PrisustvoProvider>();

    return switch (provider.state) {
      PrisustvoProviderState.loading =>
        const Center(child: CircularProgressIndicator()),
      PrisustvoProviderState.error => ErrorState(
          message: provider.errorMessage ?? 'Prisustva nije moguće učitati.',
          onRetry: provider.fetch,
        ),
      PrisustvoProviderState.loaded => Column(
          children: [
            BusyBar(busy: provider.isBusy),
            Expanded(
              child: RefreshIndicator(
                onRefresh: provider.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _SummaryCard(provider: provider),
                    const SizedBox(height: 16),
                    if (provider.subjects.isEmpty)
                      const SizedBox(
                        height: 320,
                        child: EmptyState(
                          text: 'Nema evidentiranih prisustava.',
                          icon: Icons.event_busy_outlined,
                        ),
                      )
                    else
                      for (final subject in provider.subjects)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SubjectTile(
                            subject: subject,
                            onTap: subject.postBackTarget == null
                                ? null
                                : () => _showDetail(context, provider, subject),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
    };
  }

  void _showDetail(
    BuildContext context,
    PrisustvoProvider provider,
    PrisustvoSubject subject,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _DetailSheet(
        subject: subject,
        detail: provider.fetchDetail(subject),
      ),
    );
  }
}

/// Year picker plus the average attendance across subjects.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.provider});

  final PrisustvoProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subjects = provider.subjects;
    final tracked = subjects.where((s) => s.percentage > 0).toList();
    final average = tracked.isEmpty
        ? 0
        : (tracked.fold<int>(0, (sum, s) => sum + s.percentage) /
                tracked.length)
            .round();

    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _Ring(
              percentage: average,
              size: 64,
              color: scheme.onSecondaryContainer,
              track: scheme.onSecondaryContainer.withValues(alpha: 0.15),
              textColor: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prosječno prisustvo',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: scheme.onSecondaryContainer),
                  ),
                  Text(
                    'Evidentirano u ${tracked.length} od ${subjects.length} predmeta',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer
                            .withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 96,
              child: DlwmsDropdown(
                label: 'Godina',
                options: provider.yearOptions,
                value: provider.selectedYear,
                enabled: !provider.isBusy,
                onChanged: provider.setYear,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.percentage,
    required this.color,
    required this.track,
    required this.textColor,
    this.size = 48,
  });

  final int percentage;
  final Color color;
  final Color track;
  final Color textColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: percentage / 100,
            strokeWidth: size / 10,
            color: color,
            backgroundColor: track,
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Text(
              '$percentage%',
              style: TextStyle(
                fontSize: size * 0.24,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.subject, this.onTap});

  final PrisustvoSubject subject;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = StatusColors.of(context);
    final color = status.forPercentage(subject.percentage);

    final label = subject.percentage == 0
        ? 'Nema evidencije'
        : subject.percentage >= 75
            ? 'Uredno'
            : subject.percentage >= 50
                ? 'Pažnja'
                : 'Ispod granice';

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              _Ring(
                percentage: subject.percentage,
                color: color,
                track: theme.colorScheme.surfaceContainerHighest,
                textColor: theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subject.name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration:
                              BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.subject, required this.detail});

  final PrisustvoSubject subject;
  final Future<PrisustvoDetail> detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = StatusColors.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: FutureBuilder<PrisustvoDetail>(
          future: detail,
          builder: (context, snapshot) {
            final Widget body;
            if (snapshot.connectionState != ConnectionState.done) {
              body = const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError) {
              body = Text(snapshot.error.toString());
            } else if (snapshot.data!.items.isEmpty) {
              body = const Text('Nema detalja za ovaj predmet.');
            } else {
              body = Column(
                children: [
                  for (final item in snapshot.data!.items)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(item.kind,
                                    style: theme.textTheme.titleSmall),
                              ),
                              Text(
                                '${item.percentage}%',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: status.forPercentage(item.percentage),
                                ),
                              ),
                            ],
                          ),
                          if (item.attended != null)
                            Text(
                              'Prisutan/na na ${item.attended} od ${item.total} termina',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: item.percentage / 100,
                            minHeight: 8,
                            color: status.forPercentage(item.percentage),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Ukupno prisustvo: ${subject.percentage}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                body,
              ],
            );
          },
        ),
      ),
    );
  }
}
