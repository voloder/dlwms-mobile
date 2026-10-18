import 'package:dlwms_mobile/models/document.dart';
import 'package:dlwms_mobile/provider/document_provider.dart';
import 'package:dlwms_mobile/theme/app_theme.dart';
import 'package:dlwms_mobile/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DokumentiPage extends StatefulWidget {
  const DokumentiPage({super.key});

  @override
  State<DokumentiPage> createState() => _DokumentiPageState();
}

class _DokumentiPageState extends State<DokumentiPage>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _searchController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DokumentiProvider>().fetchInitial();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final provider = context.watch<DokumentiProvider>();

    return switch (provider.state) {
      DokumentiProviderState.loading =>
        const Center(child: CircularProgressIndicator()),
      DokumentiProviderState.error => ErrorState(
          message: provider.errorMessage ?? 'Dokumente nije moguće učitati.',
          onRetry: provider.fetchInitial,
        ),
      DokumentiProviderState.loaded => _LoadedDokumentiView(
          provider: provider,
          searchController: _searchController,
        ),
    };
  }
}

String _labelFor(List<DlwmsFilterOption> options, String value) =>
    options.where((o) => o.value == value).firstOrNull?.label ?? value;

class _LoadedDokumentiView extends StatelessWidget {
  const _LoadedDokumentiView({
    required this.provider,
    required this.searchController,
  });

  final DokumentiProvider provider;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final busy = provider.isBusy;
    final theme = Theme.of(context);
    final filterCount = [
      provider.selectedType,
      provider.selectedSchoolYear,
    ].where((v) => v.isNotEmpty).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  enabled: !busy,
                  textInputAction: TextInputAction.search,
                  onSubmitted: provider.setKeyword,
                  decoration: InputDecoration(
                    hintText: 'Pretraži dokumente',
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
                    suffixIcon: provider.keyword.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              searchController.clear();
                              provider.setKeyword('');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: filterCount > 0,
                label: Text('$filterCount'),
                child: IconButton.filledTonal(
                  tooltip: 'Filteri',
                  onPressed: busy ? null : () => _openFilters(context),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DlwmsDropdown(
            label: 'Predmet',
            icon: Icons.menu_book_outlined,
            options: provider.subjectOptions,
            value: provider.selectedSubject,
            enabled: !busy,
            onChanged: provider.setSubject,
          ),
        ),
        if (filterCount > 0 || provider.keyword.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              children: [
                if (provider.keyword.isNotEmpty)
                  _FilterChip(
                    label: '„${provider.keyword}”',
                    onDeleted: () {
                      searchController.clear();
                      provider.setKeyword('');
                    },
                  ),
                if (provider.selectedType.isNotEmpty)
                  _FilterChip(
                    label: _labelFor(provider.typeOptions, provider.selectedType),
                    onDeleted: () => provider.setType(''),
                  ),
                if (provider.selectedSchoolYear.isNotEmpty)
                  _FilterChip(
                    label: provider.selectedSchoolYear,
                    onDeleted: () => provider.setSchoolYear(''),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${provider.documents.length} dokumenata · stranica ${provider.currentPage}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              IconButton(
                tooltip: 'Prethodna stranica',
                onPressed: busy || !provider.hasPreviousPage
                    ? null
                    : provider.previousPage,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Sljedeća stranica',
                onPressed:
                    busy || !provider.hasNextPage ? null : provider.nextPage,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        BusyBar(busy: busy),
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.refresh,
            child: provider.documents.isEmpty
                ? const EmptyState(
                    text: 'Nema dokumenata za odabrane filtere.',
                    icon: Icons.folder_off_outlined,
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: provider.documents.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DocumentTile(
                        document: provider.documents[index],
                        provider: provider,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _openFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChangeNotifierProvider.value(
        value: provider,
        child: const _FilterSheet(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label),
        onDeleted: onDeleted,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DokumentiProvider>();
    final busy = provider.isBusy;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filteri', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DlwmsDropdown(
              label: 'Godina studija',
              icon: Icons.school_outlined,
              options: provider.yearOptions,
              value: provider.selectedYear,
              enabled: !busy,
              onChanged: provider.setYear,
            ),
            const SizedBox(height: 12),
            DlwmsDropdown(
              label: 'Vrsta',
              icon: Icons.category_outlined,
              options: provider.typeOptions,
              value: provider.selectedType,
              enabled: !busy,
              includeEmpty: true,
              onChanged: provider.setType,
            ),
            const SizedBox(height: 12),
            DlwmsDropdown(
              label: 'Školska godina',
              icon: Icons.date_range_outlined,
              options: provider.schoolYearOptions,
              value: provider.selectedSchoolYear,
              enabled: !busy,
              includeEmpty: true,
              onChanged: provider.setSchoolYear,
            ),
            const SizedBox(height: 12),
            BusyBar(busy: busy),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : provider.clearFilters,
                    child: const Text('Poništi'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Gotovo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, required this.provider});

  final DlwmsDocument document;
  final DokumentiProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final downloading = provider.downloadingId == document.id;

    final meta = [
      document.type,
      '${document.sizeKb} KB',
      if (document.date != null) DateFormat('dd.MM.yyyy').format(document.date!),
    ].join(' · ');

    return Card(
      child: InkWell(
        onTap: provider.downloadingId != null || document.postBackTarget == null
            ? null
            : () => downloadAndOpen(context, () => provider.download(document)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              FileTypeBadge(type: document.fileType),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(meta,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                    Text(
                      document.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                child: downloading
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius:
                              BorderRadius.circular(AppRadius.small + 4),
                        ),
                        child: Icon(Icons.download_rounded,
                            size: 20,
                            color: theme.colorScheme.onSecondaryContainer),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
