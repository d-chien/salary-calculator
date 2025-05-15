// lib/lunch_suggest_page.dart

import 'package:flutter/material.dart';
import 'dart:math'; // 用於 Random
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart'; // <-- 導入輪盤套件
import 'dart:async'; // <-- 導入這個，因為需要使用 StreamController


class LunchSuggestPage extends StatefulWidget {
  const LunchSuggestPage({super.key});

  @override
  State<LunchSuggestPage> createState() => _LunchSuggestPageState();
}

class _LunchSuggestPageState extends State<LunchSuggestPage> {
  // --- 狀態與變數 ---

  // 完整的午餐選項列表
  final List<String> _allLunchOptions = const [
    '牛肉麵', '滷肉飯', '排骨飯', '雞腿飯', '水餃', '鍋貼', '拉麵', '咖哩飯', '義大利麵',
    '自助餐', '便當', '炒飯', '炒麵', '陽春麵', '餛飩麵', '榨菜肉絲麵', '鴨肉飯', '火雞肉飯',
    '魚丸湯', '貢丸湯', '酸辣湯餃', '麻醬麵', '涼麵', '壽司', '生魚片', '章魚燒', '鹽酥雞',
    '臭豆腐', '蚵仔煎', '大腸麵線', '肉圓', '碗粿', '潤餅', '刈包', '胡椒餅', '蔥抓餅',
    '鹹酥雞便當', '滷味', '東山鴨頭', '雞排', '珍奶',
    'subway', '麥當勞', '肯德基', 'Poke Bowl', '漢堡', '墨西哥捲餅',
  ];

  // 目前顯示在輪盤上的 10 個隨機選項
  List<String> _currentOptions = [];

  // 輪盤最終選擇出來的選項
  String? _chosenOption;

  // 隨機數生成器
  final Random _random = Random();

  // 用於控制輪盤選擇的 StreamController
  // 當有新的 int 值被 add 到這個 Controller 時，Stream 監聽者 (FortuneWheel) 會收到通知
  // 需要使用 StreamController 而不是 ValueNotifier 來作為 FortuneWheel 的 selected Stream 來源
  late StreamController<int> _selectedOptionIndexController; // <-- 宣告 StreamController

  // --- 初始化與清理 ---
  @override
  void initState() {
    super.initState();
    // 初始化 StreamController
    _selectedOptionIndexController = StreamController<int>(); // <-- 在 initState 中初始化

    // 生成最初的 10 個隨機選項
    _generateRandomOptions();
  }

  @override
  void dispose() {
    // 關閉並清理 StreamController，避免記憶體洩漏
    _selectedOptionIndexController.close(); // <-- 在 dispose 中關閉 StreamController
    super.dispose();
  }

  // --- 邏輯函數 ---

  // 從完整的午餐選項列表中隨機選取 10 個不重複的選項
  void _generateRandomOptions() {
    if (_allLunchOptions.length < 10) {
      _currentOptions = List.from(_allLunchOptions);
      if (mounted) {
         setState(() {
           _chosenOption = null;
         });
      }
      return;
    }

    Set<String> selectedSet = {};
    while (selectedSet.length < 10) {
      final randomIndex = _random.nextInt(_allLunchOptions.length);
      selectedSet.add(_allLunchOptions[randomIndex]);
    }

    if (mounted) {
       setState(() {
         _currentOptions = selectedSet.toList();
         _chosenOption = null; // 重置選擇的選項
         // 不需要在這裡設定 Controller 的值，只有點擊啟動時才需要發出值
       });
    }
  }

  // 啟動輪盤動畫，並從當前的 10 個選項中隨機選擇一個
  void _spinWheel() async {
    if (_currentOptions.isEmpty) {
      return;
    }

    // 從目前的 10 個選項中，隨機選取一個目標索引 (0 到 9)
    final int targetIndex = _random.nextInt(_currentOptions.length);

    // 將目標索引 add 到 StreamController 中，這會觸發 FortuneWheel 接收到新值並開始動畫
    _selectedOptionIndexController.add(targetIndex); // <-- 使用 add() 方法發出值

    // 等待一段時間，模擬輪盤動畫完成
    // FortuneWheel 的動畫時間通常不是固定的，它取決於需要轉動多少圈到達目標索引。
    // 一個簡單的方式是等待一個固定的延遲，讓使用者感覺動畫已結束再顯示結果。
    // 更精確的方式是使用 FortuneWheel 的 onAnimationEnd 回調（如果它提供最終索引）。
    // 暫時使用延遲 3 秒
    await Future.delayed(const Duration(seconds: 2));

    // 延遲結束後，更新選擇的選項
    if (mounted) {
       setState(() {
         // 假設輪盤成功停止在 targetIndex 上
         _chosenOption = _currentOptions[targetIndex];
       });
    }
  }

  // 重置頁面
  void _reset() {
    _generateRandomOptions(); // 重新生成新的 10 個選項 (這也會將 _chosenOption 設為 null)
    // 不需要在這裡重置 StreamController，下一次 add 值時它會正常工作
  }

  // --- 構建 UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('午餐吃什麼？'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                '今天的十個午餐選項：',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // --- 輪盤 Widget ---
              Expanded(
                flex: 3,
                child: FortuneWheel(
                   // 將 StreamController 的 stream 傳給 selected 屬性
                   selected: _selectedOptionIndexController.stream, // <-- 現在是正確的 Stream

                   items: _currentOptions.map((option) => FortuneItem(
                     child: Text(option),
                     // 可選：設定選項樣式
                   )).toList(),
                   animateFirst: false,

                   // 其他輪盤配置
                   // onAnimationEnd 回調可以更精確地知道動畫結束，但獲取最終索引可能需要其他方式
                   // onAnimationEnd: () {
                   //   // 如果你找到方法在這裡獲取最終索引，可以解除註解並在這裡更新 _chosenOption
                   //   // debugPrint('動畫結束！');
                   // },
                ),
              ),
              const SizedBox(height: 24),

              // --- 啟動按鈕 ---
              ElevatedButton(
                onPressed: _spinWheel, // 點擊時呼叫 _spinWheel
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text('今天午餐吃什麼？'),
              ),
              const SizedBox(height: 16),

              // --- 顯示選擇的選項 ---
              if (_chosenOption != null) ...[
                const Text(
                  '幸運午餐是：',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  _chosenOption!, // 顯示選擇的選項
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                 const SizedBox(height: 24),
              ],

              // --- 重置按鈕 ---
              ElevatedButton(
                onPressed: _reset, // 點擊時呼叫 _reset
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  textStyle: const TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  backgroundColor: Colors.blueGrey,
                ),
                child: const Text('重選選項'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}