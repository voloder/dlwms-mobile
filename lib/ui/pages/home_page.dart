import 'package:dlwms_mobile/ui/pages/dokumenti_page.dart';
import 'package:dlwms_mobile/ui/pages/nastava_page.dart';
import 'package:dlwms_mobile/ui/pages/pocetna_page.dart';
import 'package:dlwms_mobile/ui/pages/prisustva_page.dart';
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
  const HomePage({super.key, this.initialIndex = 2});

  /// Tab shown first (2 = Početna).
  final int initialIndex;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late int _selectedIndex = widget.initialIndex;

  static const List<_Destination> _destinations = [
    _Destination('Nastava', Icons.school_outlined, Icons.school),
    _Destination('Dokumenti', Icons.folder_outlined, Icons.folder),
    _Destination('Početna', Icons.home_outlined, Icons.home),
    _Destination('Prisustva', Icons.event_available_outlined,
        Icons.event_available),
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          PrisustvaPage(),
          UspjehPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
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
