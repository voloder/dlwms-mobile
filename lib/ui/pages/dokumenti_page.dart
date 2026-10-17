import 'package:dlwms_mobile/models/document.dart';
import 'package:dlwms_mobile/provider/document_provider.dart';
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
    final hasFilters = provider.selectedType.isNotEmpty ||
        provider.selectedSchoolYear.isNotEmpty ||
        provider.keyword.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: searchController,
            enabled: !busy,
            textInputAction: TextInputAction.search,
            onSubmitted: provider.setKeyword,
            decoration: InputDecoration(
              hintText: 'Pretraga po ključnim riječima',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: provider.keyword.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        provider.setKeyword('');
                      },
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: DlwmsDropdown(
                  label: 'Godina',
                  options: provider.yearOptions,
                  value: provider.selectedYear,
                  enabled: !busy,
                  onChanged: provider.setYear,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DlwmsDropdown(
                  label: 'Predmet',
                  options: provider.subjectOptions,
                  value: provider.selectedSubject,
                  enabled: !busy,
                  onChanged: provider.setSubject,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DlwmsDropdown(
                  label: 'Vrsta',
                  options: provider.typeOptions,
                  value: provider.selectedType,
                  enabled: !busy,
                  includeEmpty: true,
                  onChanged: provider.setType,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DlwmsDropdown(
                  label: 'Školska godina',
                  options: provider.schoolYearOptions,
                  value: provider.selectedSchoolYear,
                  enabled: !busy,
                  includeEmpty: true,
                  onChanged: provider.setSchoolYear,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Stranica ${provider.currentPage} · ${provider.documents.length} dokument(a)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (hasFilters)
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          searchController.clear();
                          provider.clearFilters();
                        },
                  child: const Text('Poništi filtere'),
                ),
              IconButton(
                tooltip: 'Prethodna stranica',
                onPressed:
                    busy || !provider.hasPreviousPage ? null : provider.previousPage,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Sljedeća stranica',
                onPressed:
                    busy || !provider.hasNextPage ? null : provider.nextPage,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        SizedBox(height: 3, child: busy ? const LinearProgressIndicator() : null),
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.refresh,
            child: provider.documents.isEmpty
                ? const EmptyState(
                    text: 'Nema dokumenata za odabrane filtere.',
                    icon: Icons.description_outlined,
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: provider.documents.length,
                    itemBuilder: (context, index) => _DocumentTile(
                      document: provider.documents[index],
                      provider: provider,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, required this.provider});

  final DlwmsDocument document;
  final DokumentiProvider provider;

  @override
  Widget build(BuildContext context) {
    final downloading = provider.downloadingId == document.id;
    final details = [
      document.type,
      document.author,
      '${document.sizeKb} KB',
      if (document.date != null) DateFormat('dd.MM.yyyy').format(document.date!),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(iconForFileType(document.fileType)),
        title: Text(document.title),
        subtitle: Text(details),
        trailing: downloading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download),
        onTap: provider.downloadingId != null || document.postBackTarget == null
            ? null
            : () => downloadAndOpen(context, () => provider.download(document)),
      ),
    );
  }
}
