import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'home_screen.dart';
import 'screens/bos_screen.dart';
import 'screens/pengeluaran_screen.dart';
import 'screens/pemasukan_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Use GlobalKeys so we can trigger reload on each screen
  final _homeKey = GlobalKey<HomeScreenState>();
  final _bosKey = GlobalKey<BosScreenState>();
  final _pengeluaranKey = GlobalKey<PengeluaranScreenState>();
  final _pemasukanKey = GlobalKey<PemasukanScreenState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(key: _homeKey),
      BosScreen(key: _bosKey),
      PengeluaranScreen(key: _pengeluaranKey),
      PemasukanScreen(key: _pemasukanKey),
    ];
  }

  void _onTabChanged(int index) {
    setState(() => _currentIndex = index);
    // Reload data on the target page
    switch (index) {
      case 0:
        _homeKey.currentState?.reload();
        break;
      case 1:
        _bosKey.currentState?.reload();
        break;
      case 2:
        _pengeluaranKey.currentState?.reload();
        break;
      case 3:
        _pemasukanKey.currentState?.reload();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home, 'Beranda', 0),
                _buildNavItem(Icons.account_balance_wallet_outlined, 'BOS', 1),
                _buildNavItem(Icons.outbound_outlined, 'Pengeluaran', 2),
                _buildNavItem(Icons.south_west, 'Pemasukan', 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    final color = isActive ? AppColors.primary : Colors.black45;
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
