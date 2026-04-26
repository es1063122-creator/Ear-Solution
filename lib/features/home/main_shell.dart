import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../home/home_screen.dart';
import '../sound/sound_screen.dart';
import '../record/record_screen.dart';
import '../analysis/analysis_screen.dart';
import '../chat/chat_screen.dart';
import '../../core/theme/app_colors.dart';

final currentTabProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    return Scaffold(
      body: IndexedStack(
        index: currentTab,
        children: const [
          HomeScreen(), SoundScreen(), RecordScreen(), AnalysisScreen(), ChatScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.greenLight, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentTab,
          onTap: (i) => ref.read(currentTabProvider.notifier).state = i,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined),       activeIcon: Icon(Icons.home),        label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.graphic_eq_outlined), activeIcon: Icon(Icons.graphic_eq),  label: '소리'),
            BottomNavigationBarItem(icon: Icon(Icons.edit_note_outlined),  activeIcon: Icon(Icons.edit_note),   label: '기록'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined),  activeIcon: Icon(Icons.bar_chart),   label: '분석'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: '대화'),
          ],
        ),
      ),
    );
  }
}
