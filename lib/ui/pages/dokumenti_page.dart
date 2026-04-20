import 'package:dlwms_mobile/provider/document_provider.dart';
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
      context.read<DokumentiProvider>().fetchSubjects();
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
      DokumentiProviderState.error => _ErrorState(
          message: provider.errorMessage ?? 'Failed to load documents',
          onRetry: provider.fetchSubjects,
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: searchController,
            onChanged: provider.setSearchQuery,
            decoration: InputDecoration(
              hintText: 'Search by title, type or author',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: provider.searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        provider.setSearchQuery('');
                      },
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: provider.selectedSubject.isEmpty
                      ? null
                      : provider.selectedSubject,
                  decoration: const InputDecoration(labelText: 'Predmet'),
                  isExpanded: true,
                  items: provider.subjectOptions
                      .where((option) => option.value.isNotEmpty)
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.value,
                          child: Text(option.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => provider.setSubject(value ?? ''),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: provider.selectedType.isEmpty
                      ? null
                      : provider.selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  isExpanded: true,
                  items: provider.typeOptions
                      .where((option) => option.value.isNotEmpty)
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.value,
                          child: Text(option.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => provider.setType(value ?? ''),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: provider.selectedSchoolYear.isEmpty
                      ? null
                      : provider.selectedSchoolYear,
                  decoration: const InputDecoration(labelText: 'School year'),
                  isExpanded: true,
                  items: provider.schoolYearOptions
                      .where((option) => option.value.isNotEmpty)
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.value,
                          child: Text(option.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => provider.setSchoolYear(value ?? ''),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Page ${provider.currentPage}/${provider.totalPages} - ${provider.documents.length} item(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: provider.clearFilters,
                child: const Text('Clear filters'),
              ),
            ],
          ),
        ),
        Expanded(
          child: provider.documents.isEmpty
              ? const Center(child: Text('No documents found'))
              : RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    itemCount: provider.documents.length,
                    itemBuilder: (context, index) {
                      final document = provider.documents[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading: Icon(_iconForType(document.fileType)),
                          title: Text(document.title),
                          subtitle: Text(
                            '${document.type} - ${document.author} - ${document.sizeKb} KB${document.date != null ? ' - ${DateFormat('dd.MM.yyyy').format(document.date!)}' : ''}',
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'archive':
        return Icons.folder_zip_outlined;
      case 'doc':
        return Icons.description_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 38),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
