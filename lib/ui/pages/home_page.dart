import 'package:dlwms_mobile/ui/pages/dokumenti_page.dart';
import 'package:dlwms_mobile/ui/pages/nastava_page.dart';
import 'package:dlwms_mobile/ui/pages/pocetna_page.dart';
import 'package:dlwms_mobile/ui/pages/prisustva_page.dart';
import 'package:dlwms_mobile/ui/pages/uspjeh_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
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
      setState(() {
        _selectedIndex = _tabController.index;
      });
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
        leading: const Icon(Icons.menu),
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
