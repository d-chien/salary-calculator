import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart'; // 引入 intl 庫，用於時間格式化

// 需要在 pubspec.yaml 中添加 intl 依賴：
// dependencies:
//   flutter:
//     sdk: flutter
//   cupertino_icons: ^1.0.2
//   intl: ^0.19.0  # 添加這行，並運行 flutter pub get

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '薪水計算器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SalaryCalculatorPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SalaryCalculatorPage extends StatefulWidget {
  const SalaryCalculatorPage({super.key});

  @override
  State<SalaryCalculatorPage> createState() => _SalaryCalculatorPageState();
}

class _SalaryCalculatorPageState extends State<SalaryCalculatorPage> {
  // 控制輸入框的控制器
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _monthlySalaryController = TextEditingController();

  // 頁面狀態變數
  double _currentEarnings = 0.0; // 當前已賺到的金額
  bool _isWorking = false; // 是否正在計算工作狀態 (指當前時間在工作時段內)
  bool _isWorkdayFinished = false; // 今天的工作時段是否已經過去
  String _statusMessage = '請輸入資訊，然後點擊開始'; // 顯示給用戶的狀態訊息

  // 時間選擇相關變數
  TimeOfDay? _selectedStartTime; // 用戶選擇的開始時間 (只有時和分)
  TimeOfDay? _selectedEndTime;   // 用戶選擇的結束時間 (只有時和分)

  // 計算和計時相關變數
  Timer? _timer; // 定時器
  DateTime? _workStartTimeToday; // 結合今天日期和用戶選擇的開始時間
  DateTime? _workEndTimeToday;   // 結合今天日期和用戶選擇的結束時間
  Duration? _totalWorkDuration; // 總工作時長 (結束時間 - 開始時間)
  double _dailyRate = 0.0; // 今天的總日薪
  double _secondRate = 0.0; // 每秒鐘賺多少錢的費率
  double _workProgress = 0.0; // 工作進度條的進度 (0.0 to 1.0)


  // 當 Widget 被銷毀時調用，用於清理資源
  @override
  void dispose() {
    _nicknameController.dispose();
    _monthlySalaryController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // --- 時間選擇器函數 ---

  // 顯示時間選擇器並更新選中的開始時間
  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime ?? TimeOfDay.now(), // 如果沒有選過，預設為當前時間
    );
    if (picked != null && picked != _selectedStartTime) {
      setState(() {
        _selectedStartTime = picked;
      });
    }
  }

  // 顯示時間選擇器並更新選中的結束時間
  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ?? TimeOfDay.now(), // 如果沒有選過，預設為當前時間
    );
    if (picked != null && picked != _selectedEndTime) {
      setState(() {
        _selectedEndTime = picked;
      });
    }
  }

  // --- 邏輯計算相關函數 ---

  // 計算日薪和每秒費率
  void _calculateRates(double monthlySalary) {
    // 簡單假設一個月工作 22 天
    const workingDaysPerMonth = 22;
    if (monthlySalary > 0 && workingDaysPerMonth > 0) {
      _dailyRate = monthlySalary / workingDaysPerMonth;
      if (_totalWorkDuration != null && _totalWorkDuration!.inSeconds > 0) {
         _secondRate = _dailyRate / _totalWorkDuration!.inSeconds;
      } else {
         _secondRate = 0.0; // 如果總工作時長無效，費率為零
      }
    } else {
      _dailyRate = 0.0;
      _secondRate = 0.0;
    }
  }


// 開始工作計算
  void _startWork() {
    final nickname = _nicknameController.text.trim();
    final monthlySalary = double.tryParse(_monthlySalaryController.text);

    // --- 輸入驗證 ---

    // 驗證暱稱是否為空
    if (nickname.isEmpty) {
      setState(() {
        _statusMessage = '請輸入你的暱稱'; // 具體提示暱稱問題
      });
      return; // 驗證失敗，停止後續操作
    }

    // 驗證月薪是否為有效的正數
    // double.tryParse 如果解析失敗會返回 null
    if (monthlySalary == null || monthlySalary <= 0) {
      setState(() {
        // 具體提示月薪問題
        _statusMessage = '請輸入一個有效的正數月薪';
      });
      return; // 驗證失敗，停止後續操作
    }

    // 驗證時間是否已選擇
    if (_selectedStartTime == null || _selectedEndTime == null) {
       setState(() {
         _statusMessage = '請選擇工作開始時間和結束時間'; // 具體提示時間選擇問題
       });
       return; // 驗證失敗，停止後續操作
    }

    // 驗證時間區間是否有效 (結束時間在開始時間之後，且時長合理)
    // 我們需要先組合 DateTime 物件來計算時長
    final now = DateTime.now();
    final workStartTimeToday = DateTime(now.year, now.month, now.day, _selectedStartTime!.hour, _selectedStartTime!.minute);
    var workEndTimeToday = DateTime(now.year, now.month, now.day, _selectedEndTime!.hour, _selectedEndTime!.minute);

    // 處理跨午夜的情況：如果結束時間數字上早於開始時間，假設它是第二天的時間
    // 注意：這個簡單處理沒有考慮跨越多天，僅限於一天內或跨午夜一次
    if (workEndTimeToday.isBefore(workStartTimeToday)) {
        workEndTimeToday = workEndTimeToday.add(const Duration(days: 1));
    }

    final totalWorkDuration = workEndTimeToday.difference(workStartTimeToday);

    // 檢查計算出的總工作時長是否大於 0，且不超過 24 小時（符合簡單跨午夜的假設）
    if (totalWorkDuration.inSeconds <= 0 || totalWorkDuration.inHours > 24) {
         setState(() {
           _statusMessage = '請選擇有效的開始和結束時間 (結束時間需在開始時間之後，且總時長不超過24小時)';
         });
         return; // 驗證失敗，停止後續操作
    }


    // --- 輸入驗證結束 ---
    // 如果所有驗證都通過，才執行後續的計算設置和狀態更新

    // 將經過驗證的時間值賦給 State 變數，用於後續計算
    _workStartTimeToday = workStartTimeToday;
    _workEndTimeToday = workEndTimeToday;
    _totalWorkDuration = totalWorkDuration;


    // 計算日薪和每秒費率 (使用經過驗證的月薪值)
    _calculateRates(monthlySalary);

     // 再次檢查費率是否計算成功（理論上前面積分已通過，這裡通常不會失敗）
     if (_dailyRate <= 0 || _secondRate <= 0) {
         setState(() {
           _statusMessage = '計算費率時出錯，請檢查輸入'; // 通用錯誤訊息
         });
         return;
     }


    // 初始化狀態以進入計算顯示界面
    setState(() {
      // _isWorking 和 _isWorkdayFinished 的初始狀態將在第一次 _updateEarnings 調用中根據當前時間設定
      _isWorking = false;
      _isWorkdayFinished = false;
      _currentEarnings = 0.0; // 金額歸零
      _workProgress = 0.0; // 進度歸零
       _statusMessage = '準備計算...'; // 提示狀態
    });

    // 啟動定時器，定時更新金額和進度
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _updateEarnings();
    });

    // 立即調用一次更新，確保頁面載入計算界面時顯示正確的初始狀態 (如「工作尚未開始」)
    _updateEarnings();
  }

  // 定時器觸發時更新狀態
  void _updateEarnings() {
     // 如果時間或費率無效，則不做任何事
    if (_workStartTimeToday == null || _workEndTimeToday == null || _totalWorkDuration == null || _totalWorkDuration!.inSeconds <= 0 || _secondRate <= 0) {
         _timer?.cancel(); // 取消定時器
         setState(() {
           _statusMessage = '時間或費率無效，計算停止';
         });
         return;
    }

    final currentTime = DateTime.now(); // 獲取當前時間

    // 判斷當前時間相對於工作時段的位置
    bool isBeforeWork = currentTime.isBefore(_workStartTimeToday!);
    bool isAfterWork = currentTime.isAfter(_workEndTimeToday!);
    bool isDuringWork = !isBeforeWork && !isAfterWork; // 在開始時間和結束時間之間 (包含開始和結束的瞬間)

    // 計算自工作開始以來（如果在工作期間）經過的秒數
    // 如果在工作時段外，經過秒數是固定的邊界值
    int effectiveElapsedSeconds;
    if (isBeforeWork) {
      effectiveElapsedSeconds = 0; // 工作尚未開始
    } else if (isAfterWork) {
      effectiveElapsedSeconds = _totalWorkDuration!.inSeconds; // 工作已結束，經過時長等於總時長
    } else { // isDuringWork
       final elapsedDurationDuringWork = currentTime.difference(_workStartTimeToday!);
       effectiveElapsedSeconds = elapsedDurationDuringWork.inSeconds;
    }

    // 計算當前應賺到的金額 (基於有效經過秒數)
    final earnings = effectiveElapsedSeconds * _secondRate;

    // 計算工作進度 (基於有效經過秒數佔總時長的比例)
    double progress = 0.0;
     if (_totalWorkDuration!.inSeconds > 0) {
        progress = effectiveElapsedSeconds / _totalWorkDuration!.inSeconds;
        progress = max(0.0, min(1.0, progress)); // 確保進度在 0.0 到 1.0 之間
     }


    // 更新狀態
    setState(() {
      _currentEarnings = earnings;
      _workProgress = progress;
      _isWorking = isDuringWork; // 當前時間是否在工作時段內
      _isWorkdayFinished = isAfterWork; // 當前時間是否在工作時段結束之後

      // 更新狀態訊息
      if (isBeforeWork) {
         _statusMessage = '工作尚未開始...';
      } else if (isDuringWork) {
         // 可以在這裡顯示「工作進行中」或其他動態訊息
         _statusMessage = '工作進行中...';
      } else { // isAfterWork
         _statusMessage = '恭喜！今天的目標已達成！'; // 工作結束訊息
      }

      // 如果工作已結束，取消定時器
      if (_isWorkdayFinished) {
        _timer?.cancel();
      }
    });
  }

  // 重置應用程式狀態，回到初始輸入界面
  void _reset() {
     _timer?.cancel(); // 取消定時器
     setState(() {
       // 清空輸入框文本
       //_nicknameController.clear();
       //_monthlySalaryController.clear();
       // 重置時間選擇和計算相關變數
       //_selectedStartTime = null;
       //_selectedEndTime = null;
       _workStartTimeToday = null;
       _workEndTimeToday = null;
       _totalWorkDuration = null;
       _dailyRate = 0.0;
       _secondRate = 0.0;
       _currentEarnings = 0.0;
       _workProgress = 0.0;
       // 重置狀態變數
       _isWorking = false;
       _isWorkdayFinished = false;
       _statusMessage = '輸入暱稱、月薪並選擇工作時間，然後點擊開始'; // 重設狀態訊息
     });
  }

  // --- UI 構建相關函數 ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今天賺多少？'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(16.0), // 添加內邊距
            decoration: BoxDecoration( // 添加裝飾，讓界面看起來更清晰
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
            child: Builder( // 使用 Builder 獲取正確的 context 來顯示 Dialog
              builder: (BuildContext context) {
                return Column(
                  mainAxisSize: MainAxisSize.min, // Column 根據內容調整大小
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // --- 輸入界面 ---
                    if (!_isWorking && !_isWorkdayFinished && _workStartTimeToday == null) ...[ // 在開始計算前顯示輸入界面
                      const Text( // 標題
                        '開始你的計算',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 24),
                      TextField( // 暱稱輸入框
                        controller: _nicknameController,
                        decoration: const InputDecoration(
                          labelText: '你的暱稱',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline), // 添加圖標
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField( // 月薪輸入框
                        controller: _monthlySalaryController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '你的月薪 (數字)',
                          border: OutlineInputBorder(),
                           prefixIcon: Icon(Icons.attach_money), // 添加圖標
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 開始時間選擇按鈕和顯示
                      Row(
                         children: [
                           Expanded(
                             child: ElevatedButton.icon(
                               onPressed: () => _selectStartTime(context), // 點擊時顯示時間選擇器
                               icon: const Icon(Icons.access_time),
                               label: const Text('選擇開始時間'),
                             ),
                           ),
                           const SizedBox(width: 8),
                            // 顯示選中的開始時間，如果未選則顯示提示
                           Expanded(
                              child: Text(
                               _selectedStartTime == null
                                  ? '未選擇'
                                  : '開始: ${DateFormat.Hm().format(DateTime(2022, 1, 1, _selectedStartTime!.hour, _selectedStartTime!.minute))}', // 格式化顯示時間
                               textAlign: TextAlign.center,
                               style: TextStyle(fontSize: 16, color: _selectedStartTime == null ? Colors.grey : Colors.black),
                              ),
                           ),
                         ],
                      ),
                      const SizedBox(height: 12),
                      // 結束時間選擇按鈕和顯示
                      Row(
                         children: [
                           Expanded(
                             child: ElevatedButton.icon(
                               onPressed: () => _selectEndTime(context), // 點擊時顯示時間選擇器
                               icon: const Icon(Icons.access_time),
                               label: const Text('選擇結束時間'),
                             ),
                           ),
                           const SizedBox(width: 8),
                           // 顯示選中的結束時間
                            Expanded(
                               child: Text(
                               _selectedEndTime == null
                                  ? '未選擇'
                                  : '結束: ${DateFormat.Hm().format(DateTime(2022, 1, 1, _selectedEndTime!.hour, _selectedEndTime!.minute))}', // 格式化顯示時間
                                 textAlign: TextAlign.center,
                                 style: TextStyle(fontSize: 16, color: _selectedEndTime == null ? Colors.grey : Colors.black),
                               ),
                           ),
                         ],
                      ),

                      const SizedBox(height: 24),
                      ElevatedButton( // 開始計算按鈕
                        onPressed: _startWork, // 點擊時調用 _startWork 函數
                        style: ElevatedButton.styleFrom( // 自訂按鈕樣式
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                          textStyle: const TextStyle(fontSize: 18),
                          shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text('開始計算'),
                      ),
                       const SizedBox(height: 12),
                         Text( // 顯示當前狀態或錯誤訊息
                           _statusMessage,
                           textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                         ),
                    ],

                    // --- 計算顯示和結束界面 ---
                    // 在開始計算後顯示這個界面
                    if (_workStartTimeToday != null) ...[ // 只要開始計算了（設置了 _workStartTimeToday），就顯示這個界面
                      Text( // 顯示暱稱
                        '${_nicknameController.text.trim()}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                           fontSize: 28, // 暱稱字體大一點
                           fontWeight: FontWeight.bold,
                           color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text( // 顯示當前狀態訊息
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                           fontSize: _isWorkdayFinished ? 20 : 16,
                           fontWeight: _isWorkdayFinished ? FontWeight.bold : FontWeight.normal,
                           color: _isWorkdayFinished ? Colors.green : Colors.blueGrey,
                        ),
                      ),
                       const SizedBox(height: 16),

                       // 時間進度條
                       // 時間進度條
                       ClipRRect( // <--- 包裹在 ClipRRect 中
                         borderRadius: BorderRadius.circular(5), // <--- 在 ClipRRect 上設定圓角
                         child: LinearProgressIndicator(
                           value: _workProgress, // 進度值 (0.0 to 1.0)
                           backgroundColor: Colors.grey[300], // 背景顏色
                           color: _isWorking ? Colors.blueAccent : (_isWorkdayFinished ? Colors.green : Colors.orange), // 根據狀態改變顏色
                           minHeight: 10, // 高度
                           // LinearProgressIndicator 本身沒有 borderRadius 屬性，所以我們用 ClipRRect 包裹
                         ),
                       ),
                       const SizedBox(height: 8),
                       Text( // 顯示進度百分比 (可選)
                         '進度: ${(_workProgress * 100).toStringAsFixed(1)}%',
                         textAlign: TextAlign.center,
                         style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                       ),


                       const SizedBox(height: 24),

                      Text( // 提示文本
                        '今日已賺到:',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, color: Colors.blueGrey[700]),
                      ),
                      Text( // 顯示實時計算的金額
                        '${_currentEarnings.toStringAsFixed(2)} 元', // 格式化金額
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                       const SizedBox(height: 24),
                       // --- 新增的始終顯示的回到設定按鈕 ---
                       ElevatedButton(
                         onPressed: _reset, // 點擊時仍然調用 _reset 函數來回到輸入界面
                         style: ElevatedButton.styleFrom(
                           padding: const EdgeInsets.symmetric(vertical: 15.0),
                           textStyle: const TextStyle(fontSize: 18),
                           shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                           ),
                           backgroundColor: Colors.blueGrey, // 給一個不同於主色的顏色
                         ),
                         child: const Text('回到設定頁'), // 按鈕文本
                       ),
                       // --- 新按鈕結束 ---
                        
                    ],
                  ],
                );
              }
            ),
          ),
        ),
      ),
    );
  }
}