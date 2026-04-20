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

class DokumentiPageData {
  const DokumentiPageData({
    required this.documents,
    required this.subjectOptions,
    required this.typeOptions,
    required this.schoolYearOptions,
    required this.currentPage,
    required this.totalPages,
  });

  final List<DlwmsDocument> documents;
  final List<DlwmsFilterOption> subjectOptions;
  final List<DlwmsFilterOption> typeOptions;
  final List<DlwmsFilterOption> schoolYearOptions;
  final int currentPage;
  final int totalPages;
}
