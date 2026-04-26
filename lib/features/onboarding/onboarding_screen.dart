import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../home/main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  int _page = 0;

  final List<Map<String, dynamic>> _pages = [
    {'icon': Icons.hearing,          'title': 'Auris에 오신 것을\n환영합니다',   'desc': '이명과 함께 살아가는 것을\n조금 더 편안하게 만들어드릴게요'},
    {'icon': Icons.graphic_eq,       'title': '신경 디싱크 사운드',              'desc': '최신 뇌과학 연구를 기반으로\n이명을 일으키는 뇌 신경 동기화를\n조금씩 풀어드려요'},
    {'icon': Icons.vibration,        'title': '햅틱 바이모달 세션',              'desc': '소리와 진동을 동시에 활용해\n뇌를 재훈련하는 최신 치료법을\n스마트폰으로 경험하세요'},
    {'icon': Icons.favorite_outline, 'title': '매일 조금씩',                    'desc': '6주 프로그램을 꾸준히 따라가면\n이명이 조금씩 조용해질 수 있어요'},
  ];

  void _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyOnboardingDone, true);
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _ctrl,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final p = _pages[i];
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(color: AppColors.greenLight, shape: BoxShape.circle),
                      child: Icon(p['icon'], size: 48, color: AppColors.green),
                    ),
                    const SizedBox(height: 32),
                    Text(p['title'], textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    Text(p['desc'], textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                  ]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 20 : 6, height: 6,
                  decoration: BoxDecoration(
                    color: _page == i ? AppColors.green : AppColors.greenLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                )),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _page < _pages.length - 1
                    ? () => _ctrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease)
                    : _complete,
                  child: Text(_page < _pages.length - 1 ? '다음' : '시작하기'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
