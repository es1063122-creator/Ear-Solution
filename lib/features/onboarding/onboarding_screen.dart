import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
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
  double _freq = 8000;
  AudioPlayer? _player;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _loadSavedFreq();
  }

  Future<void> _loadSavedFreq() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(AppConstants.keyTinnitusFreq);
    if (saved != null && mounted) setState(() => _freq = saved);
  }

  @override
  void dispose() { _player?.dispose(); _ctrl.dispose(); super.dispose(); }

  String _label(double f) => f >= 1000
    ? '${(f/1000).toStringAsFixed(f%1000==0?0:1)}kHz' : '${f.round()}Hz';

  String _desc(double f) {
    if (f < 2000) return '낮은 웅— 소리';
    if (f < 4000) return '중저음 이명';
    if (f < 6000) return '중고음 이명';
    if (f < 8000) return '고음 삐— 소리';
    if (f < 10000) return '높은 삐— 소리 (가장 흔한)';
    return '매우 높은 고음';
  }

  Future<void> _playTone() async {
    setState(() => _playing = true);
    try {
      await _player?.stop();
      _player?.dispose();
      _player = AudioPlayer();

      // 파일로 저장 후 재생 (iOS/Android 호환)
      final wav = _buildWav(_freq, 3);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/auris_tone_test.wav');
      await file.writeAsBytes(wav);

      await _player!.setFilePath(file.path);
      await _player!.setVolume(1.0);
      await _player!.play();
      await Future.delayed(const Duration(seconds: 3));
    } catch(e) { debugPrint('톤 오류: ' + e.toString()); }
    finally { if(mounted) setState(() => _playing = false); }
  }

  Future<void> _stopTone() async {
    await _player?.stop();
    if(mounted) setState(() => _playing = false);
  }

  List<int> _buildWav(double freq, int secs) {
    const sr = 44100; final n = sr*secs; final fade = sr~/4;
    final pcm = <int>[];
    for(int i=0;i<n;i++){
      double s = sin(2*pi*freq*i/sr);
      if(i<fade) s*=i/fade;
      if(i>n-fade) s*=(n-i)/fade;
      final v = (s*18000).round().clamp(-32768,32767);
      pcm..add(v&0xFF)..add((v>>8)&0xFF);
    }
    List<int> b(int v,int c)=>List.generate(c,(i)=>(v>>(8*i))&0xFF);
    final ds=pcm.length;
    return [0x52,0x49,0x46,0x46,...b(36+ds,4),0x57,0x41,0x56,0x45,
      0x66,0x6D,0x74,0x20,...b(16,4),...b(1,2),...b(1,2),...b(sr,4),
      ...b(sr*2,4),...b(2,2),...b(16,2),0x64,0x61,0x74,0x61,...b(ds,4),...pcm];
  }

  void _next() {
    if(_page<3){ _stopTone();
      _ctrl.nextPage(duration:const Duration(milliseconds:400),curve:Curves.easeInOut);
    } else _finish();
  }

  Future<void> _finish() async {
    await _stopTone();
    final p=await SharedPreferences.getInstance();
    await p.setBool(AppConstants.keyOnboardingDone,true);
    await p.setDouble(AppConstants.keyTinnitusFreq,_freq);
    if(mounted) Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder:(_)=>const MainShell()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.greenDark,
    body: SafeArea(child: Column(children:[
      // 진행 바
      Padding(padding:const EdgeInsets.fromLTRB(24,16,24,0),
        child:Row(children:List.generate(4,(i)=>Expanded(child:Container(
          height:3, margin:EdgeInsets.only(right:i<3?6:0),
          decoration:BoxDecoration(
            color:i<=_page?AppColors.gold:Colors.white24,
            borderRadius:BorderRadius.circular(2))))))),
      Expanded(child:PageView(
        controller:_ctrl,
        physics:const NeverScrollableScrollPhysics(),
        onPageChanged:(i)=>setState(()=>_page=i),
        children:[_p0(),_p1(),_p2(),_p3()])),
    ])),
  );

  // ── 페이지 0 ──
  Widget _p0() => Padding(
    padding:const EdgeInsets.fromLTRB(28,20,28,28),
    child:Column(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      Column(children:[
        const Text('👂',style:TextStyle(fontSize:56)),
        const SizedBox(height:12),
        const Text('Auris',style:TextStyle(color:Colors.white,fontSize:40,fontWeight:FontWeight.w700)),
        const SizedBox(height:6),
        const Text('이명 사운드 케어 앱',style:TextStyle(color:AppColors.greenLight,fontSize:15)),
      ]),
      Container(
        padding:const EdgeInsets.all(18),
        decoration:BoxDecoration(color:Colors.white.withOpacity(0.08),borderRadius:BorderRadius.circular(16)),
        child:Column(children:[
          const Text('이명을 없애는 앱이 아닙니다\n이명과 함께 더 편안하게 살아가도록 도와드리는 사운드 케어 앱입니다',
            textAlign:TextAlign.center,
            style:TextStyle(color:Colors.white,fontSize:14,height:1.6)),
          const SizedBox(height:16),
          _row('🧠','뉴캐슬대학 2025 논문 기반 변조 사운드'),
          const SizedBox(height:8),
          _row('😴','수면을 돕는 사운드 믹서'),
          const SizedBox(height:8),
          _row('📊','이명 패턴 기록 및 분석'),
        ]),
      ),
      Column(children:[
        Container(
          padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
          decoration:BoxDecoration(
            color:Colors.orange.withOpacity(0.15),
            borderRadius:BorderRadius.circular(10),
            border:Border.all(color:Colors.orange.withOpacity(0.3))),
          child:const Text('⚠️ 이 앱은 의료기기가 아닙니다',
            style:TextStyle(color:Colors.orange,fontSize:11),textAlign:TextAlign.center)),
        const SizedBox(height:12),
        _btn('시작하기 →',_next),
      ]),
    ]),
  );

  // ── 페이지 1 ──
  Widget _p1() => Padding(
    padding:const EdgeInsets.fromLTRB(24,16,24,24),
    child:Column(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      Column(children:[
        const Text('내 이명 주파수 찾기',
          style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w700)),
        const SizedBox(height:6),
        const Text('내 이명과 가장 비슷한 음을 찾으세요',
          style:TextStyle(color:AppColors.greenLight,fontSize:13)),
      ]),
      Column(children:[
        Text(_label(_freq),style:const TextStyle(color:Colors.white,fontSize:60,fontWeight:FontWeight.w200)),
        const SizedBox(height:4),
        Container(
          padding:const EdgeInsets.symmetric(horizontal:16,vertical:6),
          decoration:BoxDecoration(color:AppColors.green.withOpacity(0.3),borderRadius:BorderRadius.circular(20)),
          child:Text(_desc(_freq),style:const TextStyle(color:AppColors.greenLight,fontSize:12))),
        const SizedBox(height:14),
        SliderTheme(
          data:SliderTheme.of(context).copyWith(
            activeTrackColor:AppColors.green,inactiveTrackColor:Colors.white24,
            thumbColor:AppColors.green,trackHeight:4,
            thumbShape:const RoundSliderThumbShape(enabledThumbRadius:14)),
          child:Slider(value:_freq,min:1000,max:12000,divisions:44,
            onChanged:(v){setState((){_freq=(v/250).round()*250.0;});_stopTone();})),
        const Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
          Text('1kHz',style:TextStyle(color:AppColors.textLight,fontSize:10)),
          Text('저음 ←── 고음',style:TextStyle(color:AppColors.textLight,fontSize:10)),
          Text('12kHz',style:TextStyle(color:AppColors.textLight,fontSize:10)),
        ]),
        const SizedBox(height:12),
        Wrap(spacing:6,runSpacing:6,alignment:WrapAlignment.center,
          children:[2000,3000,4000,5000,6000,7000,8000,9000,10000,12000].map((f){
            final sel=_freq==f.toDouble();
            return GestureDetector(onTap:(){setState((){_freq=f.toDouble();});_stopTone();},
              child:Container(
                padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
                decoration:BoxDecoration(
                  color:sel?AppColors.green:Colors.white12,
                  borderRadius:BorderRadius.circular(16),
                  border:Border.all(color:sel?AppColors.green:Colors.white24)),
                child:Text(_label(f.toDouble()),style:TextStyle(
                  color:sel?Colors.white:AppColors.greenLight,
                  fontSize:12,fontWeight:sel?FontWeight.w600:FontWeight.w400))));
          }).toList()),
      ]),
      Column(children:[
        GestureDetector(
          onTap: _playing ? _stopTone : _playTone,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: _playing ? Colors.white24 : AppColors.green,
              borderRadius: BorderRadius.circular(30)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_playing)
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
              else
                const Icon(Icons.volume_up, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                _playing ? '재생 중... (탭해서 정지)' : '이 소리 들어보기 (3초)',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ]))),
        const SizedBox(height:6),
        const Text('🎧 이어폰 착용 · 볼륨 낮게',style:TextStyle(color:AppColors.textLight,fontSize:11)),
        const SizedBox(height:12),
        _btn('이 주파수로 설정하기 →',_next),
        const SizedBox(height:8),
        GestureDetector(
          onTap:_next,
          child:const Text('건너뛰기 (나중에 설정)',
            style:TextStyle(color:AppColors.textLight,fontSize:12),
            textAlign:TextAlign.center)),
      ]),
    ]),
  );

  // ── 페이지 2 ──
  Widget _p2() => Padding(
    padding:const EdgeInsets.fromLTRB(24,20,24,24),
    child:Column(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      const Text('매일 이렇게 사용하세요',
        style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w700)),
      Column(children:[
        _card('01','🧠','디싱크 사운드 (핵심)',
          '처음엔 3~10분부터 시작하세요\n익숙해지면 30분, 60분으로 늘려가세요',AppColors.green),
        const SizedBox(height:10),
        _card('02','😴','수면 모드 (잠들기 전)',
          '브라운노이즈 + 타이머\n소리가 자동으로 꺼집니다',AppColors.gold),
        const SizedBox(height:10),
        _card('03','📊','오늘 기록 (선택)',
          '이명 강도 · 수면 · 스트레스\n기록이 쌓이면 내 패턴을 발견해요',AppColors.textSecond),
      ]),
      Column(children:[
        const Text('소리를 들으면 자동으로 기록됩니다\n30분 이상 → 부분완료  ·  60분 이상 → 완료',
          textAlign:TextAlign.center,
          style:TextStyle(color:AppColors.greenLight,fontSize:13,height:1.6)),
        const SizedBox(height:14),
        _btn('다음',_next),
      ]),
    ]),
  );

  // ── 페이지 3 ──
  Widget _p3() => Padding(
    padding:const EdgeInsets.fromLTRB(24,20,24,24),
    child:Column(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      const Column(children:[
        Text('🎉',style:TextStyle(fontSize:52)),
        SizedBox(height:12),
        Text('준비 완료!',style:TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w700)),
        SizedBox(height:8),
        Text('처음엔 부담 없이 시작하세요\n꾸준함이 가장 중요합니다',
          textAlign:TextAlign.center,
          style:TextStyle(color:AppColors.greenLight,fontSize:14,height:1.5)),
      ]),
      Container(
        padding:const EdgeInsets.all(16),
        decoration:BoxDecoration(color:Colors.white.withOpacity(0.08),borderRadius:BorderRadius.circular(16)),
        child:Column(children:[
          const Text('내 이명 주파수',style:TextStyle(color:AppColors.greenLight,fontSize:13)),
          const SizedBox(height:8),
          Text(_label(_freq),style:const TextStyle(color:Colors.white,fontSize:36,fontWeight:FontWeight.w300)),
          Text(_desc(_freq),style:const TextStyle(color:AppColors.greenLight,fontSize:13)),
          const SizedBox(height:8),
          const Text('케어 탭에서 언제든지 변경 가능합니다',style:TextStyle(color:AppColors.textLight,fontSize:11)),
        ])),
      Column(children:[
        Container(
          padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(
            color:Colors.orange.withOpacity(0.15),borderRadius:BorderRadius.circular(12),
            border:Border.all(color:Colors.orange.withOpacity(0.4))),
          child:const Text('⚠️ 볼륨은 항상 낮게 유지하세요\n불편·통증·이명 악화 시 즉시 중단\n이 앱은 의료기기가 아닙니다',
            textAlign:TextAlign.center,
            style:TextStyle(color:Colors.orange,fontSize:11,height:1.5))),
        const SizedBox(height:14),
        _btn('지금 바로 시작하기 →',_finish),
      ]),
    ]),
  );

  Widget _row(String icon, String text) => Row(children:[
    Text(icon,style:const TextStyle(fontSize:18)),
    const SizedBox(width:12),
    Expanded(child:Text(text,style:const TextStyle(color:Colors.white,fontSize:13))),
  ]);

  Widget _card(String step,String icon,String title,String desc,Color color) => Container(
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(
      color:Colors.white.withOpacity(0.08),borderRadius:BorderRadius.circular(14),
      border:Border.all(color:color.withOpacity(0.4))),
    child:Row(children:[
      Column(children:[
        Text(icon,style:const TextStyle(fontSize:24)),
        const SizedBox(height:2),
        Text(step,style:TextStyle(color:color,fontSize:10,fontWeight:FontWeight.w600)),
      ]),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w600)),
        const SizedBox(height:3),
        Text(desc,style:const TextStyle(color:AppColors.greenLight,fontSize:11,height:1.4)),
      ])),
    ]));

  Widget _btn(String label,VoidCallback onTap) => SizedBox(
    width:double.infinity,
    child:ElevatedButton(
      onPressed:onTap,
      style:ElevatedButton.styleFrom(
        backgroundColor:AppColors.green,
        padding:const EdgeInsets.symmetric(vertical:15),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
      child:Text(label,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w600))));
}


