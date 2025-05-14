// lib/single_mode_page.dart

import 'package:flutter/material.dart';
import 'dart:async'; // 用於 Timer
import 'dart:math'; // 用於 min/max
import 'package:intl/intl.dart'; // 用於時間格式化

import 'utils.dart'; // <-- 導入工具函數，現在時間選擇器和費率計算是從這裡來


class SingleModePage extends StatefulWidget {
  const SingleModePage({super.key});

  @override
  State<SingleModePage> createState() => _SingleModePageState();
}

class _SingleModePageState extends State<SingleModePage> {
  // --- 單人模式狀態變數 ---
  // 這些狀態變數只與單人模式相關，所以放在這裡
  String _statusMessage = '輸入暱稱、月薪並選擇工作時間，然後點擊開始';
  Timer? _timer; // 單人模式自己的定時器

  final TextEditingController _singleNicknameController = TextEditingController();
  final TextEditingController _singleMonthlySalaryController = TextEditingController();
  TimeOfDay? _selectedStartTime; // 單人模式的開始時間
  TimeOfDay? _selectedEndTime;   // 單人模式的結束時間

  DateTime? _singleWorkStartTimeToday;
  DateTime? _singleWorkEndTimeToday;
  Duration? _singleTotalWorkDuration;

  double _singleCurrentEarnings = 0.0;
  double _singleWorkProgress = 0.0;

  bool _isSingleWorking = false;
  bool _isSingleWorkdayFinished = false;

  // --- 初始化狀態 ---
  @override
  void initState() {
    super.initState();
    // 如果需要在進入頁面時進行初始化，可以在這裡添加
  }

  // --- 資源清理 ---
  @override
  void dispose() {
    // 清理控制器和定時器
    _singleNicknameController.dispose();
    _singleMonthlySalaryController.dispose();
    _timer?.cancel(); // 離開頁面時取消定時器
    super.dispose();
  }

  // --- 單人模式邏輯 ---
  void _startCalculation() {
    _timer?.cancel(); // 啟動前先取消舊定時器

    final nickname = _singleNicknameController.text.trim();
    final monthlySalary = double.tryParse(_singleMonthlySalaryController.text);

    // 輸入驗證
    if (nickname.isEmpty) {
      setState(() { _statusMessage = '請輸入你的暱稱'; }); return;
    }
    if (monthlySalary == null || monthlySalary <= 0) {
      setState(() { _statusMessage = '請輸入一個有效的正數月薪'; }); return;
    }
    if (_selectedStartTime == null || _selectedEndTime == null) {
      setState(() { _statusMessage = '請選擇工作開始時間和結束時間'; }); return;
    }

    // 計算工作時長
    final now = DateTime.now();
    final workStartTimeToday = DateTime(now.year, now.month, now.day, _selectedStartTime!.hour, _selectedStartTime!.minute);
    var workEndTimeToday = DateTime(now.year, now.month, now.day, _selectedEndTime!.hour, _selectedEndTime!.minute);

    // 處理跨午夜情況
    if (workEndTimeToday.isBefore(workStartTimeToday)) {
      workEndTimeToday = workEndTimeToday.add(const Duration(days: 1));
    }

    final totalWorkDuration = workEndTimeToday.difference(workStartTimeToday);

    // 驗證總時長
    if (totalWorkDuration.inSeconds <= 0 || totalWorkDuration.inHours > 24) {
      setState(() { _statusMessage = '請選擇有效的開始和結束時間 (結束時間需在開始時間之後，且總時長不超過24小時)'; });
      return;
    }

    // 驗證通過，初始化計算狀態
    _singleWorkStartTimeToday = workStartTimeToday;
    _singleWorkEndTimeToday = workEndTimeToday;
    _singleTotalWorkDuration = totalWorkDuration;
    _singleCurrentEarnings = 0.0;
    _singleWorkProgress = 0.0;
    _isSingleWorking = false;
    _isSingleWorkdayFinished = false;

    setState(() { _statusMessage = '準備計算...'; }); // 設定初始狀態訊息

    // 啟動定時器
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _updateCalculationDisplay(); // 定時調用更新顯示
    });

    // 立即更新一次顯示
    _updateCalculationDisplay();
  }

  void _updateCalculationDisplay() {
    final currentTime = DateTime.now(); // 獲取當前時間

    // 確保計算數據有效
    if (_singleWorkStartTimeToday == null || _singleWorkEndTimeToday == null || _singleTotalWorkDuration == null || _singleTotalWorkDuration!.inSeconds <= 0) {
       _timer?.cancel(); // 數據無效，取消定時器
        setState(() { _statusMessage = '計算數據無效'; });
        return;
    }

    // 判斷當前時間狀態 (未開始/進行中/已結束)
    bool isBeforeWork = currentTime.isBefore(_singleWorkStartTimeToday!);
    bool isAfterWork = currentTime.isAfter(_singleWorkEndTimeToday!);
    bool isDuringWork = !isBeforeWork && !isAfterWork;

    // 計算有效經過秒數
    int effectiveElapsedSeconds;
    if (isBeforeWork) {
      effectiveElapsedSeconds = 0;
    } else if (isAfterWork) {
      effectiveElapsedSeconds = _singleTotalWorkDuration!.inSeconds;
    } else { // isDuringWork
       final elapsedDurationDuringWork = currentTime.difference(_singleWorkStartTimeToday!);
       effectiveElapsedSeconds = elapsedDurationDuringWork.inSeconds;
    }

    // 計算每秒費率 (使用 utils 裡的函數)
    final monthlySalaryForRate = double.tryParse(_singleMonthlySalaryController.text) ?? 0.0;
    final singleDailyRate = monthlySalaryForRate / 22; // 假設 22 工作天
    final singleSecondRate = (_singleTotalWorkDuration!.inSeconds > 0) ? singleDailyRate / _singleTotalWorkDuration!.inSeconds : 0.0;


    // 計算當前已賺金額和進度
    final earnings = effectiveElapsedSeconds * singleSecondRate;
    double progress = 0.0;
    if (_singleTotalWorkDuration!.inSeconds > 0) {
      progress = effectiveElapsedSeconds / _singleTotalWorkDuration!.inSeconds;
      progress = max(0.0, min(1.0, progress)); // 限制在 0.0 到 1.0
    }

    // 更新狀態並觸發 UI 重繪
    setState(() {
      _singleCurrentEarnings = earnings;
      _singleWorkProgress = progress;
      _isSingleWorking = isDuringWork; // 更新工作狀態
      _isSingleWorkdayFinished = isAfterWork; // 更新工作結束狀態

      // 更新狀態訊息 (靜態文本)
      if (isBeforeWork) {
         _statusMessage = '工作尚未開始 (${DateFormat.Hm().format(_singleWorkStartTimeToday!)} 開始)...';
      } else if (isDuringWork) {
         _statusMessage = '工作進行中...'; // 靜態文本
      } else { // isAfterWork
         _statusMessage = '恭喜！今天的搖錢樹已長大！\n今天共賺了${_singleCurrentEarnings.toStringAsFixed(2)}元'; // 結束訊息
      }

      // 如果工作日結束，取消定時器
      if (_isSingleWorkdayFinished) {
        _timer?.cancel();
      }
    });
  }

  void _reset() {
     _timer?.cancel(); // 取消定時器

     setState(() {
       // 保留控制器文本和選定的時間
       // _singleNicknameController.text;
       // _singleMonthlySalaryController.text;
       // _selectedStartTime;
       // _selectedEndTime;

       // 重置計算相關狀態變數
       _singleWorkStartTimeToday = null; // 設定為 null 是回到輸入界面的關鍵判斷
       _singleWorkEndTimeToday = null;
       _singleTotalWorkDuration = null;

       _singleCurrentEarnings = 0.0; // 重置金額
       _singleWorkProgress = 0.0; // 重置進度條

       _isSingleWorking = false; // 重置狀態
       _isSingleWorkdayFinished = false; // 重置狀態

       _statusMessage = '輸入暱稱、月薪並選擇工作時間，然後點擊開始'; // 重設狀態訊息
     });
  }


  // --- 構建 UI ---
  @override
  Widget build(BuildContext context) {
    // 判斷是否顯示輸入表單
    bool showInputForm = !_isSingleWorking && !_isSingleWorkdayFinished && _singleWorkStartTimeToday == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('個人模式'), // 頁面標題
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center( // 將主要內容置中
          child: Container( // 限制最大寬度並添加樣式
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 3,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SingleChildScrollView( // 確保內容可滾動
              child: Column( // 垂直排列內容
                mainAxisSize: MainAxisSize.min, // 包裹內容高度
                mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
                crossAxisAlignment: CrossAxisAlignment.stretch, // 水平拉伸
                children: <Widget>[
                   // --- 輸入區塊 ---
                   if (showInputForm) ...[
                     const Text( // 標題
                       '設定你的計算',
                       textAlign: TextAlign.center,
                       style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                     ),
                     const SizedBox(height: 24),

                     TextField( // 暱稱輸入
                       controller: _singleNicknameController,
                       decoration: InputDecoration(
                         labelText: '你的暱稱',
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                         prefixIcon: const Icon(Icons.person_outline),
                       ),
                     ),
                     const SizedBox(height: 12),
                     TextField( // 月薪輸入
                       controller: _singleMonthlySalaryController,
                       keyboardType: TextInputType.numberWithOptions(decimal: true, signed: false),
                       decoration: InputDecoration(
                         labelText: '你的月薪 (數字)',
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.attach_money),
                       ),
                     ),
                     const SizedBox(height: 12),

                     // --- 時間選擇器 ---
                     Row(
                       children: [
                         Expanded(
                           child: ElevatedButton.icon(
                             // 使用 utils 裡的 selectStartTime 函數，並傳入回調來更新狀態
                             onPressed: () => selectStartTime(context, _selectedStartTime, (time) {
                               setState(() { _selectedStartTime = time; });
                             }),
                             icon: const Icon(Icons.access_time),
                             label: const Text('選擇開始時間'),
                           ),
                         ),
                         const SizedBox(width: 8),
                          Expanded(
                             child: Text( // 顯示選中的開始時間
                              _selectedStartTime == null
                                 ? '開始: 未選擇'
                                 : '開始: ${DateFormat.Hm().format(DateTime(2022, 1, 1, _selectedStartTime!.hour, _selectedStartTime!.minute))}',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: _selectedStartTime == null ? Colors.grey : Colors.black),
                            ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 12),

                     Row(
                       children: [
                         Expanded(
                           child: ElevatedButton.icon(
                              // 使用 utils 裡的 selectEndTime 函數，並傳入回調來更新狀態
                             onPressed: () => selectEndTime(context, _selectedEndTime, (time) {
                               setState(() { _selectedEndTime = time; });
                             }),
                             icon: const Icon(Icons.access_time),
                             label: const Text('選擇結束時間'),
                           ),
                         ),
                         const SizedBox(width: 8),
                          Expanded(
                             child: Text( // 顯示選中的結束時間
                            _selectedEndTime == null
                                 ? '結束: 未選擇'
                                 : '結束: ${DateFormat.Hm().format(DateTime(2022, 1, 1, _selectedEndTime!.hour, _selectedEndTime!.minute))}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: _selectedEndTime == null ? Colors.grey : Colors.black),
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 24),

                     // --- 開始計算按鈕 ---
                     ElevatedButton(
                       onPressed: _startCalculation, // 點擊時開始計算
                       style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 15.0),
                         textStyle: const TextStyle(fontSize: 18),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(8.0),
                         ),
                       ),
                       child: const Text('開始計算'),
                     ),
                     const SizedBox(height: 12),
                     Text( // 顯示狀態訊息
                       _statusMessage,
                       textAlign: TextAlign.center,
                       style: TextStyle(color: Colors.grey[600], fontSize: 14),
                     ),
                   ],

                   // --- 計算顯示區塊 ---
                   if (!showInputForm) ...[ // 當不顯示輸入表單時，顯示計算結果和進度
                     Text( // 顯示暱稱
                        _singleNicknameController.text.trim(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                     ),
                     const SizedBox(height: 16),

                     // 顯示狀態訊息 (靜態文本)
                     Text(
                       _statusMessage,
                       textAlign: TextAlign.center,
                       style: TextStyle(
                         fontSize: _isSingleWorkdayFinished ? 20 : 16,
                         fontWeight: _isSingleWorkdayFinished ? FontWeight.bold : FontWeight.normal,
                         color: _isSingleWorkdayFinished ? Colors.green : Colors.blueGrey,
                       ),
                     ),
                     const SizedBox(height: 16),

                     // 進度條上跑動的人偶 (LayoutBuilder + Column + Padding) - 修正結構
                     // 使用 LayoutBuilder 獲取可用寬度
                     LayoutBuilder(
                        builder: (context, constraints) {
                          // 獲取 LayoutBuilder 提供的最大可用寬度
                          final double availableWidth = constraints.maxWidth;
                          const double iconSize = 24.0; // 人偶圖示大小
                          const double progressBarHeight = 10.0; // 進度條高度

                          // 計算人偶左側的填充距離
                          final iconPaddingLeft = availableWidth * _singleWorkProgress - iconSize / 2;

                          // 將填充距離限制在邊界內
                          final clampedLeftPosition = max(0.0, min(iconPaddingLeft, availableWidth - iconSize));


                          // 使用 Column 垂直排列人偶和進度條
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start, // 子元件靠左對齊
                            mainAxisSize: MainAxisSize.min, // 包裹內容高度
                            children: [
                              Padding( // 用 Padding 控制人偶的水平位置
                                padding: EdgeInsets.only(left: clampedLeftPosition),
                                child: Icon(
                                   Icons.person_pin, // 人偶圖示
                                   size: iconSize,
                                   color: _isSingleWorking ? Colors.blue : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4.0), // 人偶和進度條之間的間距

                              SizedBox( // 設定進度條的大小
                                 height: progressBarHeight,
                                 width: availableWidth, // 寬度填滿可用空間
                                 child: ClipRRect( // 保持圓角
                                   borderRadius: BorderRadius.circular(5),
                                   child: LinearProgressIndicator(
                                     value: _singleWorkProgress, // 進度值
                                     backgroundColor: Colors.grey[300],
                                     color: _isSingleWorking ? Colors.blueAccent : (_isSingleWorkdayFinished ? Colors.green : Colors.orange),
                                     minHeight: progressBarHeight,
                                   ),
                                 ),
                              ),
                            ],
                          );
                        }
                     ),
                     const SizedBox(height: 8), // 進度條下方的間距
                     Text( // 顯示進度百分比
                       '進度: ${(_singleWorkProgress * 100).toStringAsFixed(1)}%',
                       textAlign: TextAlign.center,
                       style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                     ),

                     const SizedBox(height: 24), // 間距

                     Text( // 已賺金額提示
                       '今天已賺到:',
                       textAlign: TextAlign.center,
                       style: TextStyle(fontSize: 20, color: Colors.blueGrey[700]),
                     ),
                     Text( // 顯示實時計算的金額
                       '${_singleCurrentEarnings.toStringAsFixed(2)} 元',
                       textAlign: TextAlign.center,
                       style: const TextStyle(
                         fontSize: 48,
                         fontWeight: FontWeight.bold,
                         color: Colors.green,
                       ),
                     ),
                     const SizedBox(height: 24), // 間距

                     // --- 回到設定頁按鈕 ---
                     ElevatedButton(
                       onPressed: _reset, // 點擊時重置回到輸入界面
                       style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 15.0),
                         textStyle: const TextStyle(fontSize: 18),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(8.0),
                         ),
                         backgroundColor: Colors.blueGrey, // 灰色按鈕
                       ),
                       child: const Text('回到設定頁'),
                     ),
                   ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}