class DlwmsDocument {
  const DlwmsDocument({
    required this.id,
    required this.title,
    required this.type,
    required this.author,
    required this.fileType,
    required this.sizeKb,
    this.date,
    this.schoolYear,
    this.postBackTarget,
  });

  final String id;
  final String title;
  final String type;
  final String author;
  final String fileType;
  final int sizeKb;
  final DateTime? date;
  final String? schoolYear;

  /// `__doPostBack` target that downloads the file.
  final String? postBackTarget;
}

class DlwmsFilterOption {
  const DlwmsFilterOption({
    required this.label,
    required this.value,
    this.isSelected = false,
  });

  final String label;
  final String value;
  final bool isSelected;
}

/// A link in an ASP.NET GridView pager (`1 2 3 ... `).
class DlwmsPagerLink {
  const DlwmsPagerLink({
    required this.label,
    this.target,
  });

  final String label;

  /// Null for the current page (rendered as a `<span>`).
  final String? target;

  bool get isCurrent => target == null;
  int? get page => int.tryParse(label);
}

class DokumentiPageData {
  const DokumentiPageData({
    required this.documents,
    required this.yearOptions,
    required this.subjectOptions,
    required this.typeOptions,
    required this.schoolYearOptions,
    required this.keyword,
    required this.currentPage,
    required this.totalPages,
    required this.pagerLinks,
  });

  final List<DlwmsDocument> documents;
  final List<DlwmsFilterOption> yearOptions;
  final List<DlwmsFilterOption> subjectOptions;
  final List<DlwmsFilterOption> typeOptions;
  final List<DlwmsFilterOption> schoolYearOptions;
  final String keyword;
  final int currentPage;

  /// Highest page number visible in the pager (DLWMS shows at most 10 at once).
  final int totalPages;
  final List<DlwmsPagerLink> pagerLinks;

  /// Target that moves one page forward, if any (`2` or `...`).
  String? get nextPageTarget => _neighbour(1);

  /// Target that moves one page back, if any.
  String? get previousPageTarget => _neighbour(-1);

  bool get hasMorePages => nextPageTarget != null;

  String? _neighbour(int direction) {
    final index = pagerLinks.indexWhere((link) => link.isCurrent);
    if (index < 0) return null;
    final neighbourIndex = index + direction;
    if (neighbourIndex < 0 || neighbourIndex >= pagerLinks.length) return null;
    return pagerLinks[neighbourIndex].target;
  }
}
