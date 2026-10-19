import 'package:dlwms_mobile/services/notification_target.dart';
import 'package:dlwms_mobile/ui/pages/dokumenti_page.dart';
import 'package:dlwms_mobile/ui/pages/ispiti_page.dart';
import 'package:dlwms_mobile/ui/pages/nastava_page.dart';
import 'package:dlwms_mobile/ui/pages/pocetna_page.dart';
import 'package:dlwms_mobile/ui/pages/uspjeh_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _Destination {
  const _Destination(this.title, this.icon, this.selectedIcon);

  final String title;
  final IconData icon;
  final IconData selectedIcon;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.tab, this.request});

  /// Tab to show (e.g. after tapping a notification); Početna by default.
  final AppTab? tab;

  /// Changes with every navigation request, so asking for the same tab
  /// twice still switches back to it.
  final String? request;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late int _selectedIndex = (widget.tab ?? AppTab.pocetna).index;

  // Same order as [AppTab].
  static const List<_Destination> _destinations = [
    _Destination('Nastava', Icons.school_outlined, Icons.school),
    _Destination('Dokumenti', Icons.folder_outlined, Icons.folder),
    _Destination('Početna', Icons.home_outlined, Icons.home),
    _Destination('Ispiti', Icons.event_note_outlined, Icons.event_note),
    _Destination('Uspjeh', Icons.workspace_premium_outlined,
        Icons.workspace_premium),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _destinations.length,
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
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tab = widget.tab;
    if (tab != null &&
        (tab != oldWidget.tab || widget.request != oldWidget.request)) {
      _goTo(tab.index);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index == _selectedIndex) return;
    _tabController.animateTo(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Title that slides and fades between tabs as the user swipes.
  Widget _buildAnimatedAppBarTitle(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall;

    return AnimatedBuilder(
      animation: _tabController.animation ?? _tabController,
      builder: (context, _) {
        final double page =
            _tabController.animation?.value ?? _tabController.index.toDouble();

        final int lowerIndex =
            page.floor().clamp(0, _destinations.length - 1).toInt();
        final int upperIndex =
            page.ceil().clamp(0, _destinations.length - 1).toInt();
        final double t = (page - lowerIndex).clamp(0.0, 1.0).toDouble();

        Widget title(int index, double opacity, double dx) => Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Text(
                  _destinations[index].title,
                  style: titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );

        return SizedBox(
          height: 36,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              title(lowerIndex, 1 - t, -40 * t),
              title(upperIndex, t, 40 * (1 - t)),
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
        toolbarHeight: 64,
        titleSpacing: 20,
        title: _buildAnimatedAppBarTitle(context),
        actions: [
          if (_selectedIndex == AppTab.pocetna.index)
            IconButton(
              tooltip: 'Pretraži obavijesti',
              icon: const Icon(Icons.search_rounded),
              onPressed: () => context.push('/home/pretraga'),
            ),
          IconButton(
            tooltip: 'Postavke',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/home/postavke'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          NastavaPage(),
          DokumentiPage(),
          PocetnaPage(),
          IspitiPage(),
          UspjehPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _goTo,
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.title,
            ),
        ],
      ),
    );
  }
}
