import 'package:dlwms_mobile/models/nastava.dart';
import 'package:dlwms_mobile/provider/nastava_provider.dart';
import 'package:dlwms_mobile/ui/pages/prisustva_page.dart';
import 'package:dlwms_mobile/ui/widgets/common.dart';
import 'package:dlwms_mobile/ui/widgets/notification_card.dart';
import 'package:dlwms_mobile/ui/pages/notification_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum _NastavaSection { predmeti, prisustvo }

/// "Nastava": per-subject announcements and materials, and attendance
/// (Prisustvo), switched with a segmented control at the top.
class NastavaPage extends StatefulWidget {
  const NastavaPage({super.key});

  @override
  State<NastavaPage> createState() => _NastavaPageState();
}

class _NastavaPageState extends State<NastavaPage>
    with AutomaticKeepAliveClientMixin {
  _NastavaSection _section = _NastavaSection.predmeti;

  /// Attendance is only loaded once the user opens it.
  bool _attendanceOpened = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<_NastavaSection>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _NastavaSection.predmeti,
                  icon: Icon(Icons.menu_book_outlined),
                  label: Text('Predmeti'),
                ),
                ButtonSegment(
                  value: _NastavaSection.prisustvo,
                  icon: Icon(Icons.event_available_outlined),
                  label: Text('Prisustvo'),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (value) => setState(() {
                _section = value.first;
                if (_section == _NastavaSection.prisustvo) {
                  _attendanceOpened = true;
                }
              }),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _section.index,
            children: [
              const _PredmetiSection(),
              _attendanceOpened ? const PrisustvaPage() : const SizedBox(),
            ],
          ),
        ),
      ],
    );
  }
}

class _PredmetiSection extends StatefulWidget {
  const _PredmetiSection();

  @override
  State<_PredmetiSection> createState() => _PredmetiSectionState();
}

class _PredmetiSectionState extends State<_PredmetiSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NastavaProvider>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              SizedBox(
                width: 104,
                child: DlwmsDropdown(
                  label: 'Godina',
                  options: provider.yearOptions,
                  value: provider.selectedYear,
                  enabled: !provider.isBusy,
                  onChanged: provider.setYear,
                ),
              ),
              const SizedBox(width: 10),
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
        BusyBar(busy: provider.isBusy),
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                SectionHeader(
                  'Obavijesti iz predmeta',
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  trailing: _Count(provider.notifications.length),
                ),
                if (provider.notifications.isEmpty)
                  const _Hint(
                    icon: Icons.notifications_none_rounded,
                    text: 'Nema obavijesti za ovaj predmet.',
                  )
                else
                  for (final notification in provider.notifications)
                    NotificationCard(
                      notification: notification,
                      showSubject: false,
                      onTap: notification.url == null
                          ? null
                          : () => openAnnouncement(context, notification),
                    ),
                SectionHeader(
                  'Novi dokumenti',
                  trailing: _Count(provider.materials.length),
                ),
                if (provider.materials.isEmpty)
                  const _Hint(
                    icon: Icons.folder_off_outlined,
                    text: 'Nema novih dokumenata.',
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Column(
                        children: [
                          for (var i = 0; i < provider.materials.length; i++) ...[
                            if (i > 0) const Divider(indent: 72),
                            _MaterialTile(
                              material: provider.materials[i],
                              provider: provider,
                            ),
                          ],
                        ],
                      ),
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

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({required this.material, required this.provider});

  final DlwmsMaterial material;
  final NastavaProvider provider;

  @override
  Widget build(BuildContext context) {
    final downloading = provider.downloadingTarget == material.postBackTarget;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
      leading: FileTypeBadge(type: material.fileType),
      title: Text(material.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: material.date == null
          ? null
          : Text(DateFormat('dd.MM.yyyy · HH:mm').format(material.date!)),
      trailing: downloading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.download_rounded,
              color: Theme.of(context).colorScheme.primary),
      onTap: provider.downloadingTarget != null
          ? null
          : () => downloadAndOpen(context, () => provider.download(material)),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: scheme.onSurfaceVariant)),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: muted),
          const SizedBox(width: 10),
          Text(text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: muted)),
        ],
      ),
    );
  }
}
