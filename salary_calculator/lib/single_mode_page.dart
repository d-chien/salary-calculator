// lib/single_mode_page.dart

import 'package:flutter/material.dart';
import 'dart:async'; // 用於 Timer
import 'dart:math'; // 用於 min/max
import 'package:intl/intl.dart'; // 用於時間格式化

import 'utils.dart'; // <-- 導入工具函數


class SingleModePage extends StatefulWidget {
  const SingleModePage({super.key});

  @override
  State<SingleModePage> createState() => _SingleModePageState();
}

class _SingleModePageState extends State<SingleModePage> {
  // --- 狀態變數 ---
  // 使用 _singleWorkStartTimeToday == null 來判斷是「輸入階段」還是「計算階段」

  // 顯示給使用者的狀態/提示訊息
  String _statusMessage = '輸入暱稱、月薪並選擇工作時間，然後點擊開始計算'; // 初始訊息

  Timer? _timer; // 用於實時計算的定時器

  // 輸入控制器 (在不同階段保留值)
  final TextEditingController _singleNicknameController = TextEditingController();
  final TextEditingController _singleMonthlySalaryController = TextEditingController();
  TimeOfDay? _selectedStartTime; // 選定的開始時間
  TimeOfDay? _selectedEndTime;   // 選定的結束時間

  // 輸入驗證通過後計算並保留的值
  DateTime? _singleWorkStartTimeToday; // null 表示輸入階段，非 null 表示計算階段
  DateTime? _singleWorkEndTimeToday;
  Duration? _singleTotalWorkDuration;
  double? _salaryPerMinute; // <-- 計算出的每分鐘薪水 (可為 null，如果輸入不完整/無效)

  // 實時計算過程中更新的值
  double _singleCurrentEarnings = 0.0; // 當前累積金額
  double _singleWorkProgress = 0.0; // 進度 (0.0-1.0)
  bool _isSingleWorking = false; // 是否處於工作時段內 (用於進度條顏色等)
  bool _isSingleWorkdayFinished = false; // 工作日是否已結束 (用於進度條顏色/結束訊息)

  // --- 初始化與清理 ---
  @override
  void initState() {
    super.initState();
    // 為月薪輸入框添加監聽器，當文本改變時觸發每分鐘薪水計算顯示
    _singleMonthlySalaryController.addListener(_calculateAndDisplayRate);
    // 在 initState 結束時觸發一次計算，以防應用程式啟動時已有預填值
    _calculateAndDisplayRate();
  }

  @override
  void dispose() {
    // 移除監聽器並清理控制器
    _singleMonthlySalaryController.removeListener(_calculateAndDisplayRate);
    _singleNicknameController.dispose();
    _singleMonthlySalaryController.dispose();
    _timer?.cancel(); // 離開頁面時取消定時器
    super.dispose();
  }

  // --- 邏輯函數 ---

  // 根據目前的輸入值 (月薪, 起始時間, 結束時間) 計算並顯示每分鐘薪水
  // 在輸入欄位變動時調用
  void _calculateAndDisplayRate() {
     final monthlySalary = double.tryParse(_singleMonthlySalaryController.text);

     // 檢查所有必要的輸入是否都有效
     if (monthlySalary != null && monthlySalary > 0 && _selectedStartTime != null && _selectedEndTime != null) {
        // 根據當前日期和選定的時間計算總時長
        final now = DateTime.now();
        final workStartTimeToday = DateTime(now.year, now.month, now.day, _selectedStartTime!.hour, _selectedStartTime!.minute);
        var workEndTimeToday = DateTime(now.year, now.month, now.day, _selectedEndTime!.hour, _selectedEndTime!.minute);

        // 處理跨午夜情況
        if (workEndTimeToday.isBefore(workStartTimeToday)) {
           workEndTimeToday = workEndTimeToday.add(const Duration(days: 1));
        }

        final totalWorkDuration = workEndTimeToday.difference(workStartTimeToday);

        // 確保總時長有效且為正數
        if (totalWorkDuration.inMinutes > 0) {
           // 計算每分鐘薪水 (月薪 / 22 工作天 / 總工作分鐘數)
           final rate = (monthlySalary / 22.0) / totalWorkDuration.inMinutes;
           setState(() {
             _salaryPerMinute = rate; // 更新狀態變數
              // 可選：如果需要，可以在這裡更新狀態訊息提示費率已就緒
              // _statusMessage = '每分鐘薪水已計算完成。';
           });
        } else {
           // 總時長無效 (0 或負數)，每分鐘薪水無法計算
            setState(() {
              _salaryPerMinute = null; // 將每分鐘薪水設為 null
               _statusMessage = '請選擇有效的開始和結束時間'; // 更新狀態訊息提示時間無效
            });
        }
     } else {
        // 輸入不完整或無效，每分鐘薪水無法計算
         setState(() {
           _salaryPerMinute = null; // 將每分鐘薪水設為 null
            // 可選：根據輸入情況重置狀態訊息
            // if (_singleNicknameController.text.isEmpty || _singleMonthlySalaryController.text.isEmpty || _selectedStartTime == null || _selectedEndTime == null) {
            //    _statusMessage = '輸入暱稱、月薪並選擇工作時間，然後點擊開始計算';
            // }
         });
     }
  }


  // 處理輸入驗證並直接切換到「實時計算」階段，啟動計時器
  void _startCalculation() {
    _timer?.cancel(); // 啟動前先取消舊定時器

    final nickname = _singleNicknameController.text.trim();
    final monthlySalary = double.tryParse(_singleMonthlySalaryController.text);

    // --- 輸入驗證 (與之前相同) ---
    if (nickname.isEmpty) {
      setState(() { _statusMessage = '請輸入你的暱稱'; }); return;
    }
    if (monthlySalary == null || monthlySalary <= 0) {
      setState(() { _statusMessage = '請輸入一個有效的正數月薪'; }); return;
    }
    if (_selectedStartTime == null || _selectedEndTime == null) {
      setState(() { _statusMessage = '請選擇工作開始時間和結束時間'; }); return;
    }

    // --- 計算工作時長 (與之前相同) ---
    final now = DateTime.now();
    final workStartTimeToday = DateTime(now.year, now.month, now.day, _selectedStartTime!.hour, _selectedStartTime!.minute);
    var workEndTimeToday = DateTime(now.year, now.month, now.day, _selectedEndTime!.hour, _selectedEndTime!.minute);

    if (workEndTimeToday.isBefore(workStartTimeToday)) {
      workEndTimeToday = workEndTimeToday.add(const Duration(days: 1));
    }

    final totalWorkDuration = workEndTimeToday.difference(workStartTimeToday);

    if (totalWorkDuration.inSeconds <= 0 || totalWorkDuration.inHours > 24) {
      setState(() { _statusMessage = '請選擇有效的開始和結束時間 (結束時間需在開始時間之後，且總時長不超過24小時)'; });
      return;
    }

    // --- 輸入驗證通過 - 直接設定進入「實時計算」階段的狀態 ---
    // 儲存計算出的時長和時間點
    _singleWorkStartTimeToday = workStartTimeToday; // <-- 設定這個值標誌著進入計算階段
    _singleWorkEndTimeToday = workEndTimeToday;
    _singleTotalWorkDuration = totalWorkDuration;

    // 再次計算並儲存每分鐘薪水 (雖然在輸入階段已顯示，但為了確保計算階段使用精確值)
     if (totalWorkDuration.inMinutes > 0) {
       _salaryPerMinute = (monthlySalary / 22.0) / totalWorkDuration.inMinutes;
    } else {
       _salaryPerMinute = 0.0;
    }


    // 重置實時計算相關的變數
    _singleCurrentEarnings = 0.0; // 累積金額歸零
    _singleWorkProgress = 0.0; // 進度歸零
    _isSingleWorking = false; // 初始狀態 (在 update 裡會根據當前時間判斷)
    _isSingleWorkdayFinished = false; // 初始狀態


     // 更新狀態，觸發 UI 切換到「實時計算」顯示
     setState(() {
        // _singleWorkStartTimeToday != null 就會自動顯示計算區塊
        _statusMessage = '工作進行中...'; // 實時計算階段的初始狀態訊息
     });

    // 啟動定時器，定時更新實時顯示
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _updateCalculationDisplay(); // 這個函數負責更新實時金額和進度條
    });

    // 觸發第一次更新，顯示初始狀態
     _updateCalculationDisplay();
  }


  // 更新實時金額和進度 (只在進入「實時計算」階段後由定時器調用)
  void _updateCalculationDisplay() {
    // 這個函數的邏輯與之前相同，根據定時器觸發時的當前時間和儲存的計算數據來更新實時顯示
    // 它只負責更新 _singleCurrentEarnings, _singleWorkProgress, _isSingleWorking, _isSingleWorkdayFinished 和實時計算階段的 _statusMessage

    final currentTime = DateTime.now();

    // 確保處於有效的計算狀態，防止定時器在錯誤狀態下觸發問題
    if (_singleWorkStartTimeToday == null || _singleWorkEndTimeToday == null || _singleTotalWorkDuration == null || _singleTotalWorkDuration!.inSeconds <= 0) {
         _timer?.cancel();
        // setState 可以在這裡不調用，避免不必要的 UI 重繪
        // setState(() { _statusMessage = '計算數據無效'; });
        return;
    }

    // 判斷當前時間相對於工作時段的位置
    bool isBeforeWork = currentTime.isBefore(_singleWorkStartTimeToday!);
    bool isAfterWork = currentTime.isAfter(_singleWorkEndTimeToday!);
    bool isDuringWork = !isBeforeWork && !isAfterWork;

    // 計算在設定工作時長內的有效經過秒數
    int effectiveElapsedSeconds;
    if (isBeforeWork) {
      effectiveElapsedSeconds = 0;
    } else if (isAfterWork) {
      effectiveElapsedSeconds = _singleTotalWorkDuration!.inSeconds;
    } else { // isDuringWork
       final elapsedDurationDuringWork = currentTime.difference(_singleWorkStartTimeToday!);
       effectiveElapsedSeconds = elapsedDurationDuringWork.inSeconds;
    }

    // 計算實時累積金額 (基於經過秒數和每秒費率)
    // 每秒費率 = 月薪 / 22工作天 / 選定的總秒數
    final monthlySalaryForRate = double.tryParse(_singleMonthlySalaryController.text) ?? 0.0;
    final singleDailyRate = monthlySalaryForRate / 22;
     // 確保總時長大於 0 才能計算秒費率
    final singleSecondRate = (_singleTotalWorkDuration!.inSeconds > 0) ? singleDailyRate / _singleTotalWorkDuration!.inSeconds : 0.0;


    final earnings = effectiveElapsedSeconds * singleSecondRate;

    // 計算進度
    double progress = 0.0;
    if (_singleTotalWorkDuration!.inSeconds > 0) {
      progress = effectiveElapsedSeconds / _singleTotalWorkDuration!.inSeconds;
      progress = max(0.0, min(1.0, progress)); // 限制在 0.0 到 1.0
    }

    // 更新實時計算階段的 UI 狀態
    setState(() {
      _singleCurrentEarnings = earnings;
      _singleWorkProgress = progress;
      _isSingleWorking = isDuringWork; // 更新工作狀態 (用於進度條顏色等)
      _isSingleWorkdayFinished = isAfterWork; // 更新工作結束狀態

      // 更新實時計算階段的狀態訊息 (根據是否未開始/進行中/已結束)
      if (isBeforeWork) {
         _statusMessage = '工作尚未開始 (${DateFormat.Hm().format(_singleWorkStartTimeToday!)} 開始)...';
      } else if (isDuringWork) {
         _statusMessage = '工作進行中...'; // 實時計算階段的靜態訊息
      } else { // isAfterWork
         _statusMessage = '恭喜！今天的搖錢樹已長大！\n今天共賺了${_singleCurrentEarnings.toStringAsFixed(2)}元'; // 結束訊息
      }

      // 如果工作日已結束，取消定時器
      if (_isSingleWorkdayFinished) {
        _timer?.cancel();
      }
    });
  }

  // 重置所有狀態變數，回到初始「輸入」階段
  void _reset() {
     _timer?.cancel(); // 取消任何存在的定時器

     setState(() {
       // 重置標誌進入輸入階段
       _singleWorkStartTimeToday = null; // <-- 設定為 null，觸發 UI 顯示輸入區塊

       // 重置所有計算和顯示相關的狀態變數
       _singleWorkEndTimeToday = null;
       _singleTotalWorkDuration = null;
       _salaryPerMinute = null; // 清除計算出的每分鐘薪水顯示

       _singleCurrentEarnings = 0.0; // 累積金額歸零
       _singleWorkProgress = 0.0; // 進度歸零
       _isSingleWorking = false; // 狀態歸零
       _isSingleWorkdayFinished = false; // 狀態歸零

       _statusMessage = '輸入暱稱、月薪並選擇工作時間，然後點擊開始計算'; // 重置狀態訊息
       // 可以選擇不清空輸入框文本和選定的時間，方便使用者快速重新輸入/修改
       // _singleNicknameController.text = ''; // 如果要清空輸入框文本，解除註解
       // _singleMonthlySalaryController.text = ''; // 如果要清空輸入框文本，解除註解
       // _selectedStartTime = null; // 如果要清空選定的時間，解除註解
       // _selectedEndTime = null;
     });
     // 重置後，再次觸發每分鐘薪水計算顯示邏輯 (如果輸入框有值，會重新計算顯示)
     _calculateAndDisplayRate();
  }


  // --- 構建 UI ---
  @override
  Widget build(BuildContext context) {
    // 判斷是否顯示「輸入區塊」
    bool isInputState = _singleWorkStartTimeToday == null;

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
                BoxShadow( // 陰影效果
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

                   // --- 輸入區塊 (顯示當處於輸入階段時) ---
                   if (isInputState) ...[
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
                         Expanded( // 讓按鈕填充空間
                           child: ElevatedButton.icon(
                             // 使用 utils 裡的 selectStartTime 函數，並傳入回調來更新狀態
                             onPressed: () => selectStartTime(context, _selectedStartTime, (time) {
                               setState(() { _selectedStartTime = time; });
                                _calculateAndDisplayRate(); // <-- 當開始時間改變時，重新計算並顯示每分鐘薪水
                             }),
                             icon: const Icon(Icons.access_time),
                             label: const Text('選擇開始時間'),
                           ),
                         ),
                         const SizedBox(width: 8), // 間距
                          Expanded( // 讓文本填充空間
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
                     const SizedBox(height: 12), // 間距

                     Row(
                       children: [
                         Expanded( // 讓按鈕填充空間
                           child: ElevatedButton.icon(
                              // 使用 utils 裡的 selectEndTime 函數，並傳入回調來更新狀態
                             onPressed: () => selectEndTime(context, _selectedEndTime, (time) {
                               setState(() { _selectedEndTime = time; });
                                _calculateAndDisplayRate(); // <-- 當結束時間改變時，重新計算並顯示每分鐘薪水
                             }),
                             icon: const Icon(Icons.access_time),
                             label: const Text('選擇結束時間'),
                           ),
                         ),
                         const SizedBox(width: 8), // 間距
                          Expanded( // 讓文本填充空間
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
                     const SizedBox(height: 24), // 間距

                     // --- 條件性顯示計算出的每分鐘薪水 ---
                     // 只有當 _salaryPerMinute 不為 null 且大於 0 時才顯示這段
                     if (_salaryPerMinute != null && _salaryPerMinute! > 0) ...[
                        Text( // 每分鐘薪水標籤
                          '您的每分鐘薪水約為:',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, color: Colors.blueGrey[700]),
                        ),
                        Text( // 顯示計算出的每分鐘薪水
                          '${_salaryPerMinute!.toStringAsFixed(2)} 元', // 使用 nullable _salaryPerMinute!，保留兩位小數
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 24), // 間距，在費率顯示後和按鈕之間
                     ],
                      // 如果輸入不完整或無效，這裡不會顯示費率，使用者會看到下方的狀態訊息


                     // --- 開始計算按鈕 (點擊直接切換到「實時計算」階段) ---
                     ElevatedButton(
                       onPressed: _startCalculation, // <-- 這個按鈕觸發驗證並直接進入實時計算
                       style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 15.0),
                         textStyle: const TextStyle(fontSize: 18),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(8.0),
                         ),
                       ),
                       child: const Text('開始計算'), // <-- 按鈕文本恢復為「開始計算」
                     ),
                     const SizedBox(height: 12), // 間距
                     // 輸入階段的狀態訊息 (由 _startCalculation 或 _calculateAndDisplayRate 更新)
                     Text(
                       _statusMessage,
                       textAlign: TextAlign.center,
                       style: TextStyle(color: Colors.grey[600], fontSize: 14),
                     ),
                   ],

                   // --- 實時計算顯示區塊 (顯示當處於計算階段時) ---
                   // 判斷條件是 _singleWorkStartTimeToday 不為 null
                   if (!isInputState) ...[
                     Text( // 顯示暱稱
                        _singleNicknameController.text.trim(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                     ),
                     const SizedBox(height: 16), // 間距

                     // 顯示狀態訊息 (工作進行中 / 已結束) - 由 _updateCalculationDisplay 更新
                     Text(
                       _statusMessage,
                       textAlign: TextAlign.center,
                       style: TextStyle(
                         fontSize: _isSingleWorkdayFinished ? 20 : 16,
                         fontWeight: _isSingleWorkdayFinished ? FontWeight.bold : FontWeight.normal,
                         color: _isSingleWorkdayFinished ? Colors.green : Colors.blueGrey,
                       ),
                     ),
                     const SizedBox(height: 16), // 間距

                     // 進度條上跑動的人偶 (LayoutBuilder + Column + Padding)
                     LayoutBuilder(
                        builder: (context, constraints) {
                          final double availableWidth = constraints.maxWidth;
                          const double iconSize = 24.0;
                          const double progressBarHeight = 10.0;

                          final iconPaddingLeft = availableWidth * _singleWorkProgress - iconSize / 2;
                          final clampedLeftPosition = max(0.0, min(iconPaddingLeft, availableWidth - iconSize));

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
                                     value: _singleWorkProgress,
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

                     Text( // 已賺金額標籤
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
                       onPressed: _reset, // 點擊時重置回到輸入階段
                       style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 15.0),
                         textStyle: const TextStyle(fontSize: 18),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(8.0),
                         ),
                         backgroundColor: Colors.blueGrey,
                       ),
                       child: const Text('回到設定頁'), // 按鈕文字
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