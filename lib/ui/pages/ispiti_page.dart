import 'package:dlwms_mobile/models/ispit.dart';
import 'package:dlwms_mobile/provider/ispiti_provider.dart';
import 'package:dlwms_mobile/services/calendar_service.dart';
import 'package:dlwms_mobile/services/exam_reminders.dart';
import 'package:dlwms_mobile/theme/app_theme.dart';
import 'package:dlwms_mobile/ui/widgets/common.dart';
import 'package:dlwms_mobile/util/bs_dates.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Exam terms of the selected exam period, plus currently active tests.
class IspitiPage extends StatefulWidget {
  const IspitiPage({super.key});

  @override
  State<IspitiPage> createState() => _IspitiPageState();
}

class _IspitiPageState extends State<IspitiPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IspitiProvider>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<IspitiProvider>();

    return switch (provider.state) {
      IspitiProviderState.loading =>
        const Center(child: CircularProgressIndicator()),
      IspitiProviderState.error => ErrorState(
          message: provider.errorMessage ?? 'Termine nije moguće učitati.',
          onRetry: provider.fetch,
        ),
      IspitiProviderState.loaded => _IspitiView(provider: provider),
    };
  }
}

class _IspitiView extends StatelessWidget {
  const _IspitiView({required this.provider});

  final IspitiProvider provider;

  @override
  Widget build(BuildContext context) {
    final upcoming = provider.upcoming;
    final past = provider.past;

    return Column(
      children: [
        BusyBar(busy: provider.isBusy),
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                for (final test in provider.activeTests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ActiveTestCard(test: test),
                  ),
                _PeriodCard(provider: provider),
                if (provider.terms.isEmpty)
                  const SizedBox(
                    height: 300,
                    child: EmptyState(
                      text: 'Za ovaj rok nema objavljenih termina.',
                      icon: Icons.event_busy_outlined,
                    ),
                  ),
                if (upcoming.isNotEmpty) ...[
                  const SectionHeader('Nadolazeći ispiti',
                      padding: EdgeInsets.fromLTRB(4, 20, 4, 8)),
                  for (final term in upcoming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TermCard(term: term, provider: provider),
                    ),
                ],
                if (past.isNotEmpty) ...[
                  const SectionHeader('Prošli termini',
                      padding: EdgeInsets.fromLTRB(4, 20, 4, 8)),
                  for (final term in past.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TermCard(term: term, provider: provider),
                    ),
                ],
                const SizedBox(height: 8),
                const _RegistrationHint(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Exam period picker with a short summary.
class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.provider});

  final IspitiProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final upcoming = provider.upcoming;
    final next = upcoming.isEmpty ? null : upcoming.first;

    final summary = next == null || next.dateTime == null
        ? '${provider.terms.length} termina'
        : '${upcoming.length} nadolazećih · sljedeći '
            '${BsDates.daysFromNow(next.dateTime!)}';

    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.event_note_rounded,
                    color: scheme.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ispitni rok',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: scheme.onSecondaryContainer),
                  ),
                ),
                Text(
                  summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (provider.periods.length > 1)
              DlwmsDropdown(
                label: 'Rok',
                options: provider.periods,
                value: provider.selectedPeriod,
                enabled: !provider.isBusy,
                onChanged: provider.setPeriod,
              )
            else
              Text(
                provider.selectedPeriodName.isEmpty
                    ? 'Trenutno nema otvorenih rokova'
                    : provider.selectedPeriodName,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: scheme.onSecondaryContainer),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTestCard extends StatelessWidget {
  const _ActiveTestCard({required this.test});

  final ActiveTest test;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onCard = scheme.onPrimaryContainer;

    final details = [
      if (test.to != null) 'otvoren do ${DateFormat('HH:mm').format(test.to!)}',
      if (test.durationMinutes != null) 'traje ${test.durationMinutes} min',
    ].join(' · ');

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.small + 2),
              ),
              child: Icon(Icons.quiz_rounded, color: scheme.onPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AKTIVAN TEST',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: onCard, letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  Text(test.subject,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: onCard)),
                  Text(
                    [test.name, if (details.isNotEmpty) details].join(' · '),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: onCard.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Test se pokreće na DLWMS-u (Testovi).',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: onCard.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermCard extends StatelessWidget {
  const _TermCard({required this.term, required this.provider});

  final ExamTerm term;
  final IspitiProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = term.dateTime;
    final isPast = term.isPast();
    final reminder = provider.hasReminder(term);
    final muted = scheme.onSurfaceVariant;

    final when = [
      term.timeText,
      if (date != null) BsDates.daysFromNow(date),
    ].join(' · ');

    return Opacity(
      opacity: isPast ? 0.6 : 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              _DateTile(date: date, fallback: term.dateText, highlight: !isPast),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(term.subject, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 15, color: muted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            when,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ),
                      ],
                    ),
                    if (term.registered || term.seats.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (term.registered)
                            _Tag(
                              icon: Icons.check_circle_rounded,
                              text: 'Prijavljen',
                              color: StatusColors.of(context).good,
                            ),
                          if (term.seats.isNotEmpty)
                            _Tag(
                              icon: Icons.groups_outlined,
                              text: 'Zauzeto: ${term.seats}',
                              color: muted,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (!isPast) ...[
                IconButton(
                  tooltip: reminder ? 'Ukloni podsjetnik' : 'Podsjeti me',
                  isSelected: reminder,
                  icon: const Icon(Icons.notifications_none_rounded),
                  selectedIcon: Icon(Icons.notifications_active_rounded,
                      color: scheme.primary),
                  onPressed: () => _toggleReminder(context),
                ),
                if (CalendarService.isSupported)
                  IconButton(
                    tooltip: 'Dodaj u kalendar',
                    icon: const Icon(Icons.edit_calendar_outlined),
                    onPressed: () => _addToCalendar(context),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleReminder(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await provider.toggleReminder(term);

    final String message;
    switch (result) {
      case null:
        message = 'Podsjetnik uklonjen.';
      case ReminderResult.scheduled:
        final at = ExamReminders.reminderTime(term);
        message = at == null
            ? 'Podsjetnik postavljen.'
            : 'Podsjetnik: ${BsDates.weekday(at)} u '
                '${DateFormat('HH:mm').format(at)}.';
      case ReminderResult.tooLate:
        message = 'Prekasno za podsjetnik.';
      case ReminderResult.failed:
        message = 'Podsjetnik nije moguće postaviti. Provjeri dozvolu za '
            'obavještenja.';
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addToCalendar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.addToCalendar(term);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nije pronađena aplikacija za kalendar.')),
      );
    }
  }
}

/// Calendar-style date: big day number with month and weekday.
class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.date,
    required this.fallback,
    required this.highlight,
  });

  final DateTime? date;
  final String fallback;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background =
        highlight ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final foreground =
        highlight ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    final day = date;

    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.small + 4),
      ),
      child: day == null
          ? Text(fallback,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(color: foreground))
          : Column(
              children: [
                Text(
                  BsDates.monthShort(day).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  '${day.day}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: foreground,
                    height: 1.1,
                  ),
                ),
                Text(
                  BsDates.weekdayShort(day),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: foreground.withValues(alpha: 0.8)),
                ),
              ],
            ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text,
              style:
                  Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _RegistrationHint extends StatelessWidget {
  const _RegistrationHint();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Prijava ispita za sada je moguća samo na DLWMS-u. Podsjetnik '
              'stiže dan prije u 18:00.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
