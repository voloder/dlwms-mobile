class StudyInfo {
  const StudyInfo({
    required this.status,
    required this.enrollmentYear,
    required this.yearOfStudy,
    required this.repeatingYear,
    required this.studyMode,
    required this.enrolledSemester,
    required this.enrolledSchoolYear,
    required this.verifiedSemester,
    required this.verifiedSchoolYear,
    required this.averageGrade,
  });

  final String status;
  final String enrollmentYear;
  final String yearOfStudy;
  final String repeatingYear;
  final String studyMode;
  final String enrolledSemester;
  final String enrolledSchoolYear;
  final String verifiedSemester;
  final String verifiedSchoolYear;
  final String averageGrade;
}

class PassedExam {
  const PassedExam({
    required this.subject,
    required this.grade,
    required this.gradeDescription,
    this.date,
  });

  final String subject;
  final int? grade;
  final String gradeDescription;
  final DateTime? date;
}

class PendingExam {
  const PendingExam({
    required this.subject,
    required this.requirementMet,
    required this.requirementDate,
    required this.attempts,
  });

  final String subject;

  /// "Uslov" – whether the prerequisites for taking the exam are met.
  final bool requirementMet;
  final String requirementDate;
  final int? attempts;
}

/// Exams grouped under a heading such as "1. godina".
class ExamGroup<T> {
  const ExamGroup({required this.title, required this.exams});

  final String title;
  final List<T> exams;
}

class UspjehPageData {
  const UspjehPageData({
    required this.info,
    required this.passed,
    required this.pending,
  });

  final StudyInfo info;
  final List<ExamGroup<PassedExam>> passed;
  final List<ExamGroup<PendingExam>> pending;

  int get passedCount =>
      passed.fold(0, (sum, group) => sum + group.exams.length);
  int get pendingCount =>
      pending.fold(0, (sum, group) => sum + group.exams.length);
}
