import 'package:dlwms_mobile/provider/nastava_provider.dart';
import 'package:dlwms_mobile/ui/widgets/common.dart';
import 'package:dlwms_mobile/ui/widgets/notification_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class NastavaPage extends StatefulWidget {
  const NastavaPage({super.key});

  @override
  State<NastavaPage> createState() => _NastavaPageState();
}

class _NastavaPageState extends State<NastavaPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NastavaProvider>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<NastavaProvider>();

    return switch (provider.state) {
      NastavaProviderState.loading =>
        const Center(child: CircularProgressIndicator()),
      NastavaProviderState.error => ErrorState(
          message: provider.errorMessage ?? 'Nastavu nije moguće učitati.',
          onRetry: provider.fetch,
        ),
      NastavaProviderState.loaded => _NastavaView(provider: provider),
    };
  }
}

class _NastavaView extends StatelessWidget {
  const _NastavaView({required this.provider});

  final NastavaProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
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
              const SizedBox(width: 12),
              Expanded(
                child: DlwmsDropdown(
                  label: 'Predmet',
                  options: provider.subjectOptions,
                  value: provider.selectedSubject,
                  enabled: !provider.isBusy,
                  onChanged: provider.setSubject,
                ),
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
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                const _SectionHeader('Obavijesti iz predmeta'),
                if (provider.notifications.isEmpty)
                  const _Hint('Nema obavijesti za ovaj predmet.')
                else
                  for (final notification in provider.notifications)
                    NotificationCard(
                      notification: notification,
                      showSubject: false,
                      onTap: notification.url == null
                          ? null
                          : () => context.push('/home/obavijest',
                              extra: notification),
                    ),
                const _SectionHeader('Novi dokumenti iz predmeta'),
                if (provider.materials.isEmpty)
                  const _Hint('Nema novih dokumenata.')
                else
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final material in provider.materials)
                          ListTile(
                            leading: Icon(iconForFileType(material.fileType)),
                            title: Text(material.title),
                            subtitle: material.date == null
                                ? null
                                : Text(DateFormat('dd.MM.yyyy HH:mm')
                                    .format(material.date!)),
                            trailing: provider.downloadingTarget ==
                                    material.postBackTarget
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Icon(Icons.download,
                                    color: theme.colorScheme.primary),
                            onTap: provider.downloadingTarget != null
                                ? null
                                : () => downloadAndOpen(
                                    context, () => provider.download(material)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
