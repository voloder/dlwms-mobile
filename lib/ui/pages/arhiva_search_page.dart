import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/provider/arhiva_provider.dart';
import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/services/arhiva_service.dart';
import 'package:dlwms_mobile/theme/app_theme.dart';
import 'package:dlwms_mobile/ui/pages/notification_detail_page.dart';
import 'package:dlwms_mobile/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Search in the DLWMS announcement archive: words in the title, subject
/// and date range.
class ArhivaSearchPage extends StatelessWidget {
  const ArhivaSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ArhivaProvider(context.read<AuthProvider>().client),
      child: const _ArhivaSearchView(),
    );
  }
}

class _ArhivaSearchView extends StatefulWidget {
  const _ArhivaSearchView();

  @override
  State<_ArhivaSearchView> createState() => _ArhivaSearchViewState();
}

class _ArhivaSearchViewState extends State<_ArhivaSearchView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(ArhivaProvider provider, [ArhivaQuery? query]) {
    FocusScope.of(context).unfocus();
    provider.search((query ?? provider.query).copyWith(words: _controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ArhivaProvider>();
    final theme = Theme.of(context);
    final query = provider.query;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(provider),
            decoration: InputDecoration(
              hintText: 'Pretraži obavijesti',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
              suffixIcon: IconButton(
                tooltip: 'Traži',
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: () => _search(provider),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              children: [
                _FilterButton(
                  icon: Icons.menu_book_outlined,
                  label: query.subject.isEmpty
                      ? 'Svi predmeti'
                      : provider.subjectName(query.subject),
                  active: query.subject.isNotEmpty,
                  onTap: () => _pickSubject(context, provider),
                ),
                _FilterButton(
                  icon: Icons.date_range_outlined,
                  label: _dateLabel(query),
                  active: query.from != null || query.to != null,
                  onTap: () => _pickDates(context, provider),
                  onClear: query.from == null && query.to == null
                      ? null
                      : () => _search(
                          provider, query.copyWith(clearDates: true)),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Bilo koja riječ'),
                    selected: query.anyWord,
                    onSelected: (value) =>
                        _search(provider, query.copyWith(anyWord: value)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _Results(provider: provider)),
        ],
      ),
    );
  }

  String _dateLabel(ArhivaQuery query) {
    final format = DateFormat('dd.MM.yyyy');
    if (query.from == null && query.to == null) return 'Bilo kada';
    if (query.from != null && query.to != null) {
      return '${format.format(query.from!)} – ${format.format(query.to!)}';
    }
    if (query.from != null) return 'od ${format.format(query.from!)}';
    return 'do ${format.format(query.to!)}';
  }

  Future<void> _pickSubject(BuildContext context, ArhivaProvider provider) async {
    final subjects = provider.subjects;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Predmet',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            ListTile(
              leading: const Icon(Icons.all_inclusive_rounded),
              title: const Text('Svi predmeti'),
              selected: provider.query.subject.isEmpty,
              onTap: () => Navigator.of(context).pop(''),
            ),
            if (subjects.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            for (final subject in subjects)
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(subject.label),
                selected: provider.query.subject == subject.value,
                onTap: () => Navigator.of(context).pop(subject.value),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      _search(provider, provider.query.copyWith(subject: selected));
    }
  }

  Future<void> _pickDates(BuildContext context, ArhivaProvider provider) async {
    final now = DateTime.now();
    final query = provider.query;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2005),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: query.from != null && query.to != null
          ? DateTimeRange(start: query.from!, end: query.to!)
          : null,
      helpText: 'Objavljeno u periodu',
    );
    if (range != null) {
      _search(provider, query.copyWith(from: range.start, to: range.end));
    }
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        avatar: Icon(icon, size: 18),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
        selected: active,
        showCheckmark: false,
        onPressed: onTap,
        onDeleted: onClear,
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.provider});

  final ArhivaProvider provider;

  @override
  Widget build(BuildContext context) {
    switch (provider.state) {
      case ArhivaState.idle:
        return const EmptyState(
          text: 'Pretraži arhivu obavijesti po riječima u naslovu,\n'
              'predmetu ili datumu objave.',
          icon: Icons.manage_search_rounded,
        );
      case ArhivaState.searching:
        return const Center(child: CircularProgressIndicator());
      case ArhivaState.error:
        return ErrorState(
          message: provider.errorMessage ?? 'Pretraga nije uspjela.',
          onRetry: () => provider.search(),
        );
      case ArhivaState.results:
        break;
    }

    final results = provider.results;
    if (results.isEmpty) {
      return const EmptyState(
        text: 'Nema obavijesti za ovu pretragu.',
        icon: Icons.search_off_rounded,
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll.metrics.extentAfter < 400 &&
            provider.hasMore &&
            !provider.loadingMore) {
          provider.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: results.length + 1,
        itemBuilder: (context, index) {
          if (index == results.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: provider.loadingMore
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : provider.hasMore
                        ? OutlinedButton(
                            onPressed: provider.loadMore,
                            child: const Text('Učitaj još'),
                          )
                        : Text(
                            '${results.length} rezultata',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ResultTile(notification: results[index]),
          );
        },
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.notification});

  final DlwmsNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = notification.dateTime;

    return Card(
      child: InkWell(
        onTap: notification.url == null
            ? null
            : () => openAnnouncement(context, notification),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.small + 2),
                ),
                child: Column(
                  children: [
                    Text('${date.day}.${date.month}.',
                        style: theme.textTheme.labelLarge),
                    Text('${date.year}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [
                        DateFormat('HH:mm').format(date),
                        if (notification.subject.isNotEmpty)
                          notification.subject,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
