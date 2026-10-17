import 'package:dlwms_mobile/models/prisustvo.dart';
import 'package:dlwms_mobile/provider/prisustvo_provider.dart';
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: DlwmsDropdown(
                      label: 'Godina studija',
                      options: provider.yearOptions,
                      value: provider.selectedYear,
                      enabled: !provider.isBusy,
                      onChanged: provider.setYear,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Dodirni predmet za detalje',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 3,
              child: provider.isBusy ? const LinearProgressIndicator() : null,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: provider.refresh,
                child: provider.subjects.isEmpty
                    ? const EmptyState(
                        text: 'Nema evidentiranih prisustava.',
                        icon: Icons.event_busy,
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: provider.subjects.length,
                        itemBuilder: (context, index) {
                          final subject = provider.subjects[index];
                          return _SubjectTile(
                            subject: subject,
                            onTap: subject.postBackTarget == null
                                ? null
                                : () => _showDetail(context, provider, subject),
                          );
                        },
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
      showDragHandle: true,
      builder: (context) => _DetailSheet(
        subject: subject,
        detail: provider.fetchDetail(subject),
      ),
    );
  }
}

Color _colorFor(BuildContext context, int percentage) {
  if (percentage >= 75) return Colors.green;
  if (percentage >= 50) return Colors.orange;
  if (percentage > 0) return Colors.red;
  return Theme.of(context).colorScheme.outline;
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.subject, this.onTap});

  final PrisustvoSubject subject;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context, subject.percentage);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    '${subject.percentage}%',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: subject.percentage / 100,
                  minHeight: 6,
                  color: color,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: FutureBuilder<PrisustvoDetail>(
          future: detail,
          builder: (context, snapshot) {
            final theme = Theme.of(context);

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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(item.kind,
                                    style: theme.textTheme.bodyLarge),
                              ),
                              if (item.attended != null)
                                Text(
                                  '${item.attended}/${item.total} termina · ',
                                  style: theme.textTheme.bodySmall,
                                ),
                              Text(
                                '${item.percentage}%',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: _colorFor(context, item.percentage),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: item.percentage / 100,
                            minHeight: 6,
                            color: _colorFor(context, item.percentage),
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
                    style: theme.textTheme.bodyMedium),
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
