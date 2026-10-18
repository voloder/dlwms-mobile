import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/provider/notification_provider.dart';
import 'package:dlwms_mobile/services/background_service.dart';
import 'package:dlwms_mobile/services/check_status.dart';
import 'package:dlwms_mobile/ui/pages/dokumenti_page.dart';
import 'package:dlwms_mobile/ui/pages/nastava_page.dart';
import 'package:dlwms_mobile/ui/pages/pocetna_page.dart';
import 'package:dlwms_mobile/ui/pages/prisustva_page.dart';
import 'package:dlwms_mobile/ui/pages/uspjeh_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedIndex = 2;

  static const List<String> _pageTitles = [
    'Nastava',
    'Dokumenti',
    'Početna',
    'Prisustva',
    'Uspjeh',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _pageTitles.length,
      vsync: this,
      initialIndex: _selectedIndex,
    );

    _tabController.addListener(() {
      if (_selectedIndex != _tabController.index) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedAppBarTitle(BuildContext context) {
    final titleStyle = Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge;

    return AnimatedBuilder(
      animation: _tabController.animation ?? _tabController,
      builder: (context, _) {
        final double page =
            _tabController.animation?.value ?? _tabController.index.toDouble();

        final int lowerIndex =
            page.floor().clamp(0, _pageTitles.length - 1).toInt();
        final int upperIndex =
            page.ceil().clamp(0, _pageTitles.length - 1).toInt();
        final double t = (page - lowerIndex).clamp(0.0, 1.0).toDouble();

        return SizedBox(
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 1 - t,
                child: Transform.translate(
                  offset: Offset(-100 * t, 0),
                  child: Transform.scale(
                    scale: 1 - 0.2 * t,
                    child: Text(
                      _pageTitles[lowerIndex],
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(100 * (1 - t), 0),
                  child: Transform.scale(
                    scale: 0.8 + 0.2 * t,
                    child: Text(
                      _pageTitles[upperIndex],
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Postavke',
          icon: const Icon(Icons.menu),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (_) => const _SettingsSheet(),
          ),
        ),
        title: _buildAnimatedAppBarTitle(context),
        centerTitle: true,
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          NastavaPage(),
          DokumentiPage(),
          PocetnaPage(),
          PrisustvaPage(),
          UspjehPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == _selectedIndex) return;

          _tabController.animateTo(
            index,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );

          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Nastava',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Dokumenti',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Početna',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note),
            label: 'Prisustva',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grade),
            label: 'Uspjeh',
          ),
        ],
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notifications = context.watch<NotificationProvider>();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(auth.username ?? 'Student'),
              subtitle: const Text('DLWMS · FIT'),
            ),
            const Divider(),
            const _SectionLabel('Obavijesti'),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Provjera obavijesti u pozadini'),
              subtitle: Text(_backgroundDescription(auth)),
              value:
                  BackgroundService.isSupported && auth.backgroundCheckEnabled,
              onChanged: BackgroundService.isSupported
                  ? auth.setBackgroundCheckEnabled
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 24, 8),
              child: Text(_lastCheckText(notifications.lastCheck), style: muted),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.filter_alt_outlined),
              title: const Text('Prikaži samo relevantne obavijesti'),
              subtitle: const Text(
                'Predmeti tvoje godine studija i oni bez ocjene. '
                'Opće obavijesti se uvijek prikazuju.',
              ),
              value: notifications.relevantOnly,
              onChanged: notifications.setRelevantOnly,
            ),
            if (notifications.relevantOnly)
              _RelevantSubjectsTile(provider: notifications),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Odjava'),
              onTap: () {
                Navigator.of(context).pop();
                auth.logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _backgroundDescription(AuthProvider auth) {
    if (!BackgroundService.isSupported) {
      return 'Svakih 5 minuta dok je aplikacija otvorena.';
    }
    if (auth.backgroundCheckEnabled && !auth.backgroundRunning) {
      return 'Nije pokrenuta. Provjeri dozvolu za obavještenja.';
    }
    return 'Svakih 5 minuta, i kad je aplikacija zatvorena.';
  }

  static String _lastCheckText(CheckStatus? status) {
    if (status == null) return 'Zadnja provjera: još nije bilo provjere.';

    final now = DateTime.now();
    final sameDay = status.time.year == now.year &&
        status.time.month == now.month &&
        status.time.day == now.day;
    final when = DateFormat(sameDay ? 'HH:mm' : 'dd.MM. HH:mm').format(status.time);

    final result = switch (status.result) {
      CheckResult.ok => status.newCount == 0
          ? 'nema novih obavijesti'
          : 'novih obavijesti: ${status.newCount}',
      CheckResult.authFailed => 'prijava nije uspjela, otvorite aplikaciju',
      CheckResult.error => 'nije uspjela, pokušava ponovo za 5 minuta',
    };
    return 'Zadnja provjera u $when · $result';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// Shows which subjects currently count as relevant.
class _RelevantSubjectsTile extends StatelessWidget {
  const _RelevantSubjectsTile({required this.provider});

  final NotificationProvider provider;

  @override
  Widget build(BuildContext context) {
    final subjects = provider.relevantSubjects;
    final loading = provider.loadingRelevantSubjects;

    final String subtitle;
    if (loading && subjects == null) {
      subtitle = 'Učitavam predmete...';
    } else if (subjects == null || subjects.isEmpty) {
      subtitle = 'Lista predmeta nije učitana, pa se zasad prikazuju sve '
          'obavijesti.';
    } else {
      subtitle = subjects.join(', ');
    }

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(72, 0, 8, 0),
      title: Text(subjects == null
          ? 'Relevantni predmeti'
          : 'Relevantni predmeti (${subjects.length})'),
      subtitle: Text(subtitle),
      trailing: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              tooltip: 'Osvježi listu predmeta',
              icon: const Icon(Icons.refresh),
              onPressed: () => provider.refreshRelevantSubjects(force: true),
            ),
    );
  }
}
