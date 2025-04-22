import 'package:flutter/material.dart'; // Flutter UI 元件庫
import 'dart:async'; // 用於 Timer 定時器
import 'dart:math'; // 用於 min 函數
import 'package:intl/intl.dart'; // 用於時間格式化
import 'package:community_charts_flutter/community_charts_flutter.dart' as charts; // 用於繪製圖表

// --- 資料類別 ---

// 會議模式中，用於輸入框的成員資料和控制器
class MeetingMemberInput {
  TextEditingController nicknameController;
  TextEditingController salaryController;

  MeetingMemberInput({
    required this.nicknameController,
    required this.salaryController,
  });

  // 銷毀控制器，避免記憶體洩漏
  void dispose() {
    nicknameController.dispose();
    salaryController.dispose();
  }
}

// 會議模式中，用於計算和顯示的成員資料
class MeetingMemberData {
  String nickname;
  double monthlySalary;
  double secondRate; // 根據月薪計算出的每秒費率 (基於工作天數和工時)
  double currentEarnings; // 會議進行中時，該成員累積賺到的金額

  MeetingMemberData({
    required this.nickname,
    required this.monthlySalary,
    required this.secondRate,
    this.currentEarnings = 0.0,
  });
}

// 用於柱狀圖的資料類別
class SalaryCost {
  final String member; // 與會人員暱稱
  final double cost; // 會議結束時，該人員的總薪水花費 (即總收入)

  SalaryCost(this.member, this.cost);
}


// --- 應用程式進入點 ---

void main() {
  runApp(const MyApp());
}

// --- 應用程式根 Widget ---

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '種下您今天的搖錢樹 Make every second counts',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // 移除 debug 標誌，在 Web 上更整潔
      debugShowCheckedModeBanner: false,
      // 設定首頁 Widget
      home: const SalaryCalculatorPage(),
    );
  }
}

// --- 主要薪水計算頁面 Widget ---

class SalaryCalculatorPage extends StatefulWidget {
  const SalaryCalculatorPage({super.key});

  @override
  State<SalaryCalculatorPage> createState() => _SalaryCalculatorPageState();
}

// --- 頁面狀態管理 ---

class _SalaryCalculatorPageState extends State<SalaryCalculatorPage> {
  // --- 共用狀態變數 ---
  String _statusMessage = '選擇模式，輸入資訊，然後點擊開始'; // 顯示給用戶的狀態訊息
  Timer? _timer; // 定時器物件

  // --- 單人模式狀態變數 ---
  final TextEditingController _singleNicknameController = TextEditingController();
  final TextEditingController _singleMonthlySalaryController = TextEditingController();
  TimeOfDay? _selectedStartTime; // 用戶選擇的開始時間 (共用)
  TimeOfDay? _selectedEndTime;   // 用戶選擇的結束時間 (共用，但會議模式輸入時隱藏)

  DateTime? _singleWorkStartTimeToday; // 結合今天日期和單人模式選定的開始時間 (計算用)
  DateTime? _singleWorkEndTimeToday;   // 結合今天日期和單人模式選定的結束時間 (計算用)
  Duration? _singleTotalWorkDuration; // 單人模式總工作時長 (計算用)

  double _singleCurrentEarnings = 0.0; // 單人模式當前已賺金額 (顯示用)
  double _singleWorkProgress = 0.0; // 單人模式進度條進度 (顯示用)

  bool _isSingleWorking = false; // 單人模式：當前時間是否在工作時段內
  bool _isSingleWorkdayFinished = false; // 單人模式：今天的工作時段是否已經過去

  // --- 會議模式狀態變數 ---
  bool _meetingMode = false; // 是否處於會議模式

  List<MeetingMemberInput> _meetingMembersInput = []; // 會議模式：與會人員輸入框控制器列表 (輸入用)
  List<MeetingMemberData> _meetingMembersData = []; // 會議模式：與會人員數據列表 (計算和顯示用)

  DateTime? _meetingStartTime; // 會議開始的精確時間 (點擊開始會議時設定)
  DateTime? _meetingEndTime; // 會議結束的精確時間 (點擊結束會議時設定)
  Duration? _meetingDuration; // 會議的總時長 (會議結束時計算)

  bool _isMeetingActive = false; // 會議模式：會議是否正在進行中 (計時器運行)
  bool _isMeetingEnded = false; // 會議模式：會議是否已經結束 (點擊了結束按鈕)

  final int _minMeetingMembers = 1; // 會議模式最少成員數
  final int _maxMeetingMembers = 20; // 會議模式最多成員數

  // --- 初始化狀態 ---
  @override
  void initState() {
    super.initState();
    // 應用程式啟動時，初始化會議模式的預設成員輸入框數量
    _initializeMeetingMembersInput(_minMeetingMembers); // 預設為最少成員數
  }

  // 初始化/重新初始化會議成員輸入框控制器列表
  void _initializeMeetingMembersInput(int count) {
    // 確保不會超過最大限制
    count = min(count, _maxMeetingMembers);
    for (int i = 0; i < count; i++) {
      _meetingMembersInput.add(MeetingMemberInput(
        nicknameController: TextEditingController(),
        salaryController: TextEditingController(),
      ));
    }
  }

  // --- 資源清理 ---
  @override
  void dispose() {
    // 清理單人模式控制器
    _singleNicknameController.dispose();
    _singleMonthlySalaryController.dispose();

    // 清理會議模式控制器列表中的所有控制器
    for (var memberInput in _meetingMembersInput) {
      memberInput.dispose();
    }

    // 取消定時器（如果存在且正在運行）
    _timer?.cancel();

    super.dispose();
  }

  // --- 時間選擇器函數 (共用) ---

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

  // --- 費率計算函數 ---

  // 根據月薪計算每秒費率 (假設每月工作 22 天，每天工作 8 小時)
  double _calculateSecondRate(double monthlySalary) {
    const workingDaysPerMonth = 22;
    const hoursPerDay = 8;
    const secondsPerHour = 3600;

    if (monthlySalary > 0) {
      final dailyRate = monthlySalary / workingDaysPerMonth;
      final hourlyRate = dailyRate / hoursPerDay;
      return hourlyRate / secondsPerHour;
    }
    return 0.0; // 月薪無效則費率為零
  }


  // --- 開始計算/會議邏輯 ---
  void _startCalculation() {
    _timer?.cancel(); // 取消任何可能正在運行的定時器

    if (!_meetingMode) {
      // --- 單人模式：啟動計算 ---

      final nickname = _singleNicknameController.text.trim();
      final monthlySalary = double.tryParse(_singleMonthlySalaryController.text);

      // 輸入驗證 (單人模式)
      if (nickname.isEmpty) {
        setState(() { _statusMessage = '請輸入你的暱稱'; }); return;
      }
      if (monthlySalary == null || monthlySalary <= 0) {
        setState(() { _statusMessage = '請輸入一個有效的正數月薪'; }); return;
      }
      if (_selectedStartTime == null || _selectedEndTime == null) {
        setState(() { _statusMessage = '請選擇工作開始時間和結束時間'; }); return;
      }

      // 結合今天的日期和選定的時間來計算總時長
      final now = DateTime.now();
      final workStartTimeToday = DateTime(now.year, now.month, now.day, _selectedStartTime!.hour, _selectedStartTime!.minute);
      var workEndTimeToday = DateTime(now.year, now.month, now.day, _selectedEndTime!.hour, _selectedEndTime!.minute);

      // 簡單處理跨午夜情況：如果結束時間在開始時間之前，假設是第二天的時間
      if (workEndTimeToday.isBefore(workStartTimeToday)) {
        workEndTimeToday = workEndTimeToday.add(const Duration(days: 1));
      }

      final totalWorkDuration = workEndTimeToday.difference(workStartTimeToday);

      // 驗證計算出的總工作時長是否有效 (大於 0 且不超過 24 小時)
      if (totalWorkDuration.inSeconds <= 0 || totalWorkDuration.inHours > 24) {
        setState(() { _statusMessage = '請選擇有效的開始和結束時間 (結束時間需在開始時間之後，且總時長不超過24小時)'; });
        return;
      }

      // 驗證通過，設定單人模式的計算相關狀態變數
      _singleWorkStartTimeToday = workStartTimeToday;
      _singleWorkEndTimeToday = workEndTimeToday;
      _singleTotalWorkDuration = totalWorkDuration;
      _singleCurrentEarnings = 0.0;
      _singleWorkProgress = 0.0;
      _isSingleWorking = false; // 初始狀態，實際在 update 中判斷
      _isSingleWorkdayFinished = false; // 初始狀態

      // 初始化狀態訊息
      setState(() { _statusMessage = '準備計算...'; });

      // 啟動定時器，定時更新單人模式顯示
      _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        _updateCalculationDisplay();
      });

      // 立即調用一次更新，顯示正確的初始狀態
      _updateCalculationDisplay();

    } else {
      // --- 會議模式：啟動計算 (開始會議) ---

      if (_selectedStartTime == null) {
         setState(() { _statusMessage = '請選擇會議開始時間'; }); return;
      }

      // 驗證所有與會人員的輸入
      List<MeetingMemberData> membersData = [];
      for (var memberInput in _meetingMembersInput) {
        final nickname = memberInput.nicknameController.text.trim();
        final monthlySalary = double.tryParse(memberInput.salaryController.text);

        if (nickname.isEmpty || monthlySalary == null || monthlySalary <= 0) {
          setState(() { _statusMessage = '請檢查所有與會人員的暱稱和月薪 (需為有效的正數)'; }); return; // 驗證失敗
        }

        // 計算該成員的每秒費率
        final secondRate = _calculateSecondRate(monthlySalary);

        if (secondRate <= 0) {
             setState(() { _statusMessage = '計算與會人員費率時出錯'; }); return; // 費率計算失敗
        }

        // 將驗證通過的成員數據添加到列表中
        membersData.add(MeetingMemberData(
          nickname: nickname,
          monthlySalary: monthlySalary,
          secondRate: secondRate,
          currentEarnings: 0.0, // 初始化收入為零
        ));
      }

      // 如果沒有任何與會人員
      if (membersData.isEmpty) {
          setState(() { _statusMessage = '請至少添加一位與會人員'; }); return;
      }

      // 如果所有驗證都通過
      _meetingMembersData = membersData; // 將驗證好的數據賦給 State 變數
      _meetingStartTime = DateTime.now(); // 設定會議開始的精確時間
      _meetingEndTime = null; // 結束時間在開始時未設定
      _meetingDuration = null; // 總時長在結束時才計算
      _isMeetingActive = true; // 設定會議狀態為進行中
      _isMeetingEnded = false; // 設定會議狀態為未結束

      // 初始化狀態訊息
      setState(() { _statusMessage = '會議進行中...'; });

      // 啟動定時器，定時更新會議模式顯示 (成員收入和持續時間)
      _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        _updateCalculationDisplay();
      });

      // 立即調用一次更新，顯示正確的初始狀態 (會議持續時間從零開始)
      _updateCalculationDisplay();
    }
  }

  // --- 更新顯示邏輯 (共用) ---
  void _updateCalculationDisplay() {
    final currentTime = DateTime.now(); // 獲取當前時間

    if (!_meetingMode) {
      // --- 單人模式：更新顯示 (金額、進度條) ---
       // 確保計算數據有效，否則取消定時器並顯示錯誤
       if (_singleWorkStartTimeToday == null || _singleWorkEndTimeToday == null || _singleTotalWorkDuration == null || _singleTotalWorkDuration!.inSeconds <= 0) {
          _timer?.cancel();
           setState(() { _statusMessage = '計算數據無效'; });
           return;
       }

      // 判斷當前時間相對於工作時段的位置
      bool isBeforeWork = currentTime.isBefore(_singleWorkStartTimeToday!);
      bool isAfterWork = currentTime.isAfter(_singleWorkEndTimeToday!);
      bool isDuringWork = !isBeforeWork && !isAfterWork; // 在開始和結束時間之間 (包含邊界)

      // 計算在設定工作時長內的有效經過秒數
      int effectiveElapsedSeconds;
      if (isBeforeWork) {
        effectiveElapsedSeconds = 0; // 工作尚未開始，經過時長為 0
      } else if (isAfterWork) {
        effectiveElapsedSeconds = _singleTotalWorkDuration!.inSeconds; // 工作已結束，經過時長等於總時長
      } else { // isDuringWork
         final elapsedDurationDuringWork = currentTime.difference(_singleWorkStartTimeToday!);
         effectiveElapsedSeconds = elapsedDurationDuringWork.inSeconds;
      }

      // 計算單人模式的每秒費率 (這裡需要重新計算，因為它依賴於總工作時長)
      final monthlySalaryForRate = double.tryParse(_singleMonthlySalaryController.text) ?? 0.0;
      final singleDailyRate = monthlySalaryForRate / 22; // 假設 22 工作天計算日薪
      // 確保總時長大於 0 才能計算秒費率
      final singleSecondRate = (_singleTotalWorkDuration!.inSeconds > 0) ? singleDailyRate / _singleTotalWorkDuration!.inSeconds : 0.0;


      // 計算當前應賺到的金額 (基於有效經過秒數和費率)
      final earnings = effectiveElapsedSeconds * singleSecondRate;

      // 計算工作進度 (基於有效經過秒數佔總時長的比例)
      double progress = 0.0;
      if (_singleTotalWorkDuration!.inSeconds > 0) {
        progress = effectiveElapsedSeconds / _singleTotalWorkDuration!.inSeconds;
        progress = max(0.0, min(1.0, progress)); // 確保進度在 0.0 到 1.0 之間
      }

      // 使用 setState 更新 UI 相關的狀態變數
      setState(() {
        _singleCurrentEarnings = earnings;
        _singleWorkProgress = progress;
        _isSingleWorking = isDuringWork; // 當前時間是否在設定的工作時段內
        _isSingleWorkdayFinished = isAfterWork; // 當前時間是否已過了設定的工作結束時間

        // 更新狀態訊息
        if (isBeforeWork) {
           _statusMessage = '工作尚未開始 (${DateFormat.Hm().format(_singleWorkStartTimeToday!)} 開始)...';
        } else if (isDuringWork) {
           _statusMessage = '工作進行中...';
        } else { // isAfterWork
           _statusMessage = '恭喜！今天的搖錢樹已長大！\n今天共賺了${earnings.toStringAsFixed(2)}元'; // 工作日結束訊息
        }

        // 如果工作日已經結束，取消定時器
        if (_isSingleWorkdayFinished) {
          _timer?.cancel();
        }
      });

    } else {
      // --- 會議模式：更新顯示 (成員實時收入，會議持續時間) ---

      // 如果會議不是進行中或已經結束，則不做任何事 (計時器應該被取消或不應運行)
      if (!_isMeetingActive || _meetingStartTime == null || _isMeetingEnded) {
         _timer?.cancel(); // 再次確保計時器被取消
         return;
      }

      final elapsedDuration = currentTime.difference(_meetingStartTime!); // 計算從會議開始到當前的總經過時間
      final elapsedSeconds = elapsedDuration.inSeconds.toDouble(); // 轉換為秒數 (使用 double 避免潛在的溢出)

      if (elapsedSeconds < 0) { // 理論上不會發生
          setState(() { _statusMessage = '時間錯誤'; _isMeetingActive = false; });
           _timer?.cancel();
           return;
      }

      // 更新每一個與會人員的實時累積收入
      setState(() {
         for (var memberData in _meetingMembersData) {
           // 收入 = 總經過秒數 * 該人員的每秒費率
           memberData.currentEarnings = elapsedSeconds * memberData.secondRate;
         }

         // 更新狀態訊息以顯示會議持續時間
         final hours = elapsedDuration.inHours;
         final minutes = elapsedDuration.inMinutes.remainder(60);
         final seconds = elapsedDuration.inSeconds.remainder(60);
         _statusMessage = '會議進行中... 已持續 ${hours}時 ${minutes}分 ${seconds}秒';
      });
    }
  }

  // --- 會議結束邏輯 ---
  void _endMeeting() {
    // 只有在會議進行中且開始時間已設定時，才能結束會議
    if (_isMeetingActive && _meetingStartTime != null) {
      _timer?.cancel(); // 停止定時器

      final endTime = DateTime.now(); // 記錄會議結束的精確時間
      final duration = endTime.difference(_meetingStartTime!); // 計算總時長

      // 根據精確的總時長，重新計算每個成員的最終收入
       for (var memberData in _meetingMembersData) {
           memberData.currentEarnings = duration.inSeconds.toDouble() * memberData.secondRate;
       }

      // 使用 setState 更新狀態，顯示會議結束畫面
      setState(() {
        _meetingEndTime = endTime; // 設定結束時間
        _meetingDuration = duration; // 設定總時長
        _isMeetingActive = false; // 設定會議狀態為非進行中
        _isMeetingEnded = true; // 設定會議狀態為已結束

        // 更新狀態訊息顯示最終總時長
        final hours = duration.inHours;
        final minutes = duration.inMinutes.remainder(60);
        final seconds = duration.inSeconds.remainder(60);
        _statusMessage = '會議已結束！總時長 ${hours}時 ${minutes}分 ${seconds}秒';
      });
    }
  }


  // --- 重置邏輯 (處理兩種模式) ---
  // 將應用程式狀態重置為初始輸入界面，但保留已輸入的數據 (單人模式)
  // 會議模式重置會清空成員列表，並重新初始化為預設數量
  void _reset() {
     _timer?.cancel(); // 取消任何可能正在運行的定時器

     if (!_meetingMode) {
       // --- 單人模式：重置計算和顯示相關狀態 ---
       setState(() {
         // 保留 _singleNicknameController, _singleMonthlySalaryController 的文本內容
         // 保留 _selectedStartTime 和 _selectedEndTime 的值

         // 重置單人模式計算和顯示相關的狀態變數
         _singleWorkStartTimeToday = null; // 設為 null 是回到單人模式輸入界面的關鍵
         _singleWorkEndTimeToday = null;
         _singleTotalWorkDuration = null;

         _singleCurrentEarnings = 0.0; // 重置金額
         _singleWorkProgress = 0.0; // 重置進度條

         _isSingleWorking = false; // 重置狀態
         _isSingleWorkdayFinished = false; // 重置狀態

         _statusMessage = '輸入暱稱、月薪並選擇工作時間，然後點擊開始'; // 重設狀態訊息
       });
     } else { // --- 會議模式：重置所有會議相關狀態 ---
       setState(() {
         // 銷毀並清空舊的成員輸入控制器列表
         for(var memberInput in _meetingMembersInput) {
           memberInput.dispose();
         }
         _meetingMembersInput.clear();

         // 重新初始化預設數量的成員輸入控制器列表
         _initializeMeetingMembersInput(_minMeetingMembers);

         _meetingMembersData.clear(); // 清空會議成員數據列表
         _meetingStartTime = null; // 重置會議時間和時長
         _meetingEndTime = null;
         _meetingDuration = null;

         _isMeetingActive = false; // 重置狀態
         _isMeetingEnded = false;

         // 單人模式的變數在這裡不需要重置，因為它們不是會議模式的狀態
         // _singleCurrentEarnings = 0.0; // <-- 這些變數屬於單人模式，在這裡不需要操作
         // _singleWorkProgress = 0.0;    // <--

         _statusMessage = '輸入與會人員資訊，然後點擊開始會議'; // 會議模式的初始狀態訊息
         // 保留 _selectedStartTime 和 _selectedEndTime 的值 (如果用戶想為下次會議保留開始時間選擇)
       });
     }
     // Note: _meetingMode state is NOT reset here, it persists until toggled by the Switch
  }

  // --- 會議模式：添加與會人員輸入框 ---
  void _addMeetingMemberInput() {
    // 檢查是否達到最大成員限制
    if (_meetingMembersInput.length < _maxMeetingMembers) {
      setState(() {
        // 向輸入列表添加一個新的成員輸入控制器
        _meetingMembersInput.add(MeetingMemberInput(
          nicknameController: TextEditingController(),
          salaryController: TextEditingController(),
        ));
      });
    } else {
       // 如果達到限制，顯示提示訊息
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('最多只能添加 20 位與會人員')),
       );
    }
  }

  // --- 構建 UI 元件函數 ---

  // 構建單個會議成員的輸入行 (在會議模式輸入界面使用)
  Widget _buildMeetingMemberInputRow(MeetingMemberInput memberInput, int index) {
    return Card( // 使用 Card 包裹，提供視覺分隔
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // 文本靠左對齊
          children: [
             // 顯示成員編號 (從 1 開始)
             Text('與會人員 ${index + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
             const SizedBox(height: 8), // 間距
             // 暱稱輸入框
             TextField(
              controller: memberInput.nicknameController,
              decoration: InputDecoration(
                labelText: '暱稱',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true, // 使輸入框更緊湊
              ),
             ),
             const SizedBox(height: 8), // 間距
             // 月薪輸入框
             TextField(
              controller: memberInput.salaryController,
              keyboardType: TextInputType.numberWithOptions(decimal: true, signed: false), // 數字鍵盤，允許小數，不允許負號
              decoration: InputDecoration(
                labelText: '月薪 (數字)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                 isDense: true, // 使輸入框更緊湊
              ),
             ),
          ],
        ),
      ),
    );
  }

  // 構建單個會議成員的顯示行 (在會議模式進行中顯示)
  Widget _buildMeetingMemberDisplayRow(MeetingMemberData memberData) {
      // 使用 ListTile 呈現更清晰的列表項
      return ListTile(
        leading: CircleAvatar( // 左側圓形頭像/圖標
          backgroundColor: Colors.blueAccent,
          // 顯示暱稱的第一個字母，如果暱稱為空顯示問號
          child: Text(memberData.nickname.isNotEmpty ? memberData.nickname[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white)),
        ),
        title: Text(memberData.nickname), // 顯示暱稱
        // trailing 顯示該成員當前賺到的金額，保留兩位小數
        trailing: Text('${memberData.currentEarnings.toStringAsFixed(2)} 元',
             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        // subtitle 顯示原始月薪 (可選)
        subtitle: Text('月薪: ${memberData.monthlySalary.toStringAsFixed(0)}'),
      );
  }

  // 構建柱狀圖 (在會議模式結束後顯示)
  Widget _buildBarChart(List<MeetingMemberData> membersData) {
    // 準備用於圖表的數據列表
    // 將 MeetingMemberData 轉換為 SalaryCost 格式
    final List<SalaryCost> data = membersData.map((member) => SalaryCost(member.nickname, member.currentEarnings)).toList();

    // 創建圖表系列列表
    final List<charts.Series<SalaryCost, String>> series = [
      charts.Series<SalaryCost, String>(
        id: '會議成本', // 系列的 ID
        domainFn: (SalaryCost cost, _) => cost.member, // X 軸數據：成員暱稱
        measureFn: (SalaryCost cost, _) => cost.cost,   // Y 軸數據：薪水花費
        data: data, // 圖表數據來源
        // 可選：設定柱狀圖顏色
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        // 可選：在柱狀圖頂部顯示數值標籤
        labelAccessorFn: (SalaryCost cost, _) => '${cost.cost.toStringAsFixed(0)}', // 顯示金額，不帶小數點
         // 可選：設定渲染器，用於顯示標籤
        // rendererId: 'basicBar', // 可以自定義渲染器 ID
      )
       // 如果需要多個系列，可以在這裡添加更多 charts.Series 物件
    ];

    // 創建柱狀圖 Widget
    final chart = charts.BarChart(
      series, // 圖表數據系列
      animate: true, // 啟用動畫效果
       // 可選：添加圖表行為 (如滑鼠懸停提示)
       behaviors: [
          // 這個行為用於選擇最接近的圖表元素
          charts.SelectNearest(
            eventTrigger: charts.SelectionTrigger.tapAndDrag // 設置觸發方式
          ),
          // <--- 用 LinePointHighlighter 替換原來的 HoverCard --->
          // 添加 LinePointHighlighter 行為，它會在選中或懸停時高亮數據點並顯示預設提示卡
          charts.LinePointHighlighter(), // 使用 LinePointHighlighter 行為

          // ... 其他可能的行為 ...
       ],
        // 可選：自定義軸線
        domainAxis: charts.OrdinalAxisSpec(
           // 如果 X 軸標籤可能過長或重疊，可以選擇隱藏軸線或旋轉標籤
           // renderSpec: charts.NoneRenderSpec(), // 隱藏整個 X 軸
           // renderSpec: charts.SmallTickRendererSpec(labelRotation: 45), // 旋轉標籤
           // 可選：設置軸線標題
           // showAxisLine: true, // 顯示軸線本身
        ),
         // 可選：隱藏 Y 軸，因為值已經顯示在柱狀圖上
         // measureAxis: charts.NumericAxisSpec(renderSpec: charts.NoneRenderSpec()),
         // 可選：設置 Y 軸標題
         // primaryMeasureAxis: charts.NumericAxisSpec(title: '薪水花費 (元)'),
    );

     // 將圖表包裹在一個具有固定高度的容器中，避免佈局問題
     // 高度可以根據成員數量動態調整，但設定一個最大值
     return Container(
        height: min(300.0, membersData.length * 60.0 + 50), // 根據成員數量調整高度，加一些額外空間，設定最大值
        padding: const EdgeInsets.symmetric(vertical: 16.0), // 添加一些垂直內邊距
        child: chart,
     );
  }


  // --- 構建方法 ---
  @override
  Widget build(BuildContext context) {
    return Scaffold( // 提供基本的應用程式結構
      appBar: AppBar( // 應用程式頂部欄
        title: const Text('種下您今天的搖錢樹 Make every second counts'), // 標題
        centerTitle: true, // 標題居中
      ),
      body: Padding( // 為 body 內容添加內邊距
        padding: const EdgeInsets.all(16.0),
        child: Center( // 將內容居中
          child: Container( // 使用 Container 限制最大寬度並添加裝飾
            constraints: const BoxConstraints(maxWidth: 600), // 設定最大寬度，會議模式可能需要更寬
            padding: const EdgeInsets.all(16.0), // 內部填充
            decoration: BoxDecoration( // 裝飾 (背景色、圓角、陰影)
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 3,
                  blurRadius: 5,
                  offset: const Offset(0, 3), // 陰影偏移
                ),
              ],
            ),
            child: Builder( // 使用 Builder 獲取正確的 Context，以便顯示 Dialog (如時間選擇器) 或 SnackBar
              builder: (BuildContext context) {
                return SingleChildScrollView( // 使用 SingleChildScrollView 防止內容溢出 (特別是多個成員輸入時)
                  child: Column( // 垂直排列內容
                    mainAxisSize: MainAxisSize.min, // 讓 Column 根據子 Widget 總高度調整自身大小
                    mainAxisAlignment: MainAxisAlignment.center, // 垂直居中對齊
                    crossAxisAlignment: CrossAxisAlignment.stretch, // 子 Widget 水平拉伸填滿
                    children: <Widget>[
                       // --- 模式切換開關 ---
                       SwitchListTile( // 列表項形式的開關
                          title: const Text('啟用會議(老闆)模式：可計算同場會議整體消耗了多少的薪水'), // 標題
                          value: _meetingMode, // 開關的當前值
                          onChanged: (bool value) {
                             // 當開關狀態改變時，重置所有狀態並切換模式
                             _reset(); // 先重置當前模式的狀態
                             setState(() {
                               _meetingMode = value; // 切換模式狀態
                               // 根據新模式設定初始狀態訊息
                               _statusMessage = _meetingMode ? '輸入與會人員資訊，然後點擊開始會議' : '輸入暱稱、月薪並選擇工作時間，然後點擊開始';
                             });
                          },
                       ),
                       const Divider(), // 在模式開關下方添加分隔線

                      // --- 輸入界面 (根據模式和狀態條件顯示) ---
                      // 只有在不是正在計算/會議中/結束狀態時顯示輸入界面
                      // 單人模式輸入條件：不在單人計算/結束狀態 且 單人開始時間未設定 (初始狀態)
                      // 會議模式輸入條件：不在會議進行中/結束狀態
                      if ((!_meetingMode && !_isSingleWorking && !_isSingleWorkdayFinished && _singleWorkStartTimeToday == null) ||
                          (_meetingMode && !_isMeetingActive && !_isMeetingEnded)) ...[

                         const Text( // 標題
                           '設定你的計算', // 標題文本
                           textAlign: TextAlign.center, // 文本居中
                           style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                         ),
                         const SizedBox(height: 24), // 間距

                         if (!_meetingMode) ...[ // --- 單人模式輸入 ---
                           TextField( // 暱稱輸入框
                             controller: _singleNicknameController, // 控制器
                             decoration: InputDecoration( // 裝飾
                               labelText: '你的暱稱', // 標籤
                               border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), // 邊框樣式
                               prefixIcon: const Icon(Icons.person_outline), // 左側圖標
                             ),
                           ),
                           const SizedBox(height: 12), // 間距
                           TextField( // 月薪輸入框
                             controller: _singleMonthlySalaryController, // 控制器
                             keyboardType: TextInputType.numberWithOptions(decimal: true, signed: false), // 數字鍵盤，允許小數，不允許負號
                             decoration: InputDecoration( // 裝飾
                               labelText: '你的月薪 (數字)', // 標籤
                               border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), // 邊框樣式
                                prefixIcon: const Icon(Icons.attach_money), // 左側圖標
                             ),
                           ),
                           const SizedBox(height: 12), // 間距
                         ],

                         // --- 時間選擇器行 (共用，但結束時間在會議模式輸入時隱藏) ---
                         Row(
                           children: [
                             Expanded( // 讓按鈕填充可用空間
                               child: ElevatedButton.icon( // 帶圖標的按鈕
                                 onPressed: () => _selectStartTime(context), // 點擊時調用選擇開始時間函數
                                 icon: const Icon(Icons.access_time), // 圖標
                                 label: const Text('選擇開始時間'), // 按鈕文本
                               ),
                             ),
                             const SizedBox(width: 8), // 間距
                              Expanded( // 讓文本填充可用空間
                                 child: Text( // 顯示選中的開始時間
                                  _selectedStartTime == null
                                     ? '開始: 未選擇' // 未選擇時顯示提示
                                     // 格式化顯示選中的時間 (例如 14:30)
                                     : '開始: ${DateFormat.Hm().format(DateTime(2022, 1, 1, _selectedStartTime!.hour, _selectedStartTime!.minute))}',
                                  textAlign: TextAlign.center, // 文本居中
                                  style: TextStyle(fontSize: 16, color: _selectedStartTime == null ? Colors.grey : Colors.black),
                                 ),
                             ),
                           ],
                         ),
                         const SizedBox(height: 12), // 間距

                         if (!_meetingMode) ...[ // --- 結束時間選擇器行 (僅在單人模式顯示) ---
                           Row(
                             children: [
                               Expanded( // 讓按鈕填充可用空間
                                 child: ElevatedButton.icon( // 帶圖標的按鈕
                                   onPressed: () => _selectEndTime(context), // 點擊時調用選擇結束時間函數
                                   icon: const Icon(Icons.access_time), // 圖標
                                   label: const Text('選擇結束時間'), // 按鈕文本
                                 ),
                               ),
                               const SizedBox(width: 8), // 間距
                                Expanded( // 讓文本填充可用空間
                                   child: Text( // 顯示選中的結束時間
                                  _selectedEndTime == null
                                     ? '結束: 未選擇' // 未選擇時顯示提示
                                     // 格式化顯示選中的時間 (例如 17:00)
                                     : '結束: ${DateFormat.Hm().format(DateTime(2022, 1, 1, _selectedEndTime!.hour, _selectedEndTime!.minute))}',
                                   textAlign: TextAlign.center, // 文本居中
                                   style: TextStyle(fontSize: 16, color: _selectedEndTime == null ? Colors.grey : Colors.black),
                                  ),
                               ),
                             ],
                           ),
                           const SizedBox(height: 24), // 單人模式按鈕前的間距
                         ],


                         if (_meetingMode) ...[ // --- 會議模式輸入 ---
                           const SizedBox(height: 12), // 間距
                           // 使用 ListView.builder 顯示多個與會人員輸入框
                           // shrinkWrap 和 NeverScrollableScrollPhysics 防止與外層 SingleChildScrollView 衝突
                           ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _meetingMembersInput.length, // 列表項數量等於成員輸入控制器的數量
                              itemBuilder: (context, index) {
                                 // 為每個成員構建一個輸入行 Widget
                                 return _buildMeetingMemberInputRow(_meetingMembersInput[index], index);
                              },
                           ),
                           const SizedBox(height: 8), // 間距
                           // 添加與會人員按鈕 (只有在未達到最大限制時顯示)
                           if (_meetingMembersInput.length < _maxMeetingMembers)
                              ElevatedButton.icon(
                                onPressed: _addMeetingMemberInput, // 點擊時調用添加成員函數
                                icon: const Icon(Icons.add), // 圖標
                                label: Text('添加與會人員 (${_meetingMembersInput.length}/${_maxMeetingMembers})'), // 顯示當前數量和最大限制
                                style: ElevatedButton.styleFrom( // 自訂按鈕樣式
                                   backgroundColor: Colors.green, // 不同顏色
                                   padding: const EdgeInsets.symmetric(vertical: 12.0),
                                   textStyle: const TextStyle(fontSize: 16),
                                   shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                   ),
                                ),
                              ),
                           const SizedBox(height: 24), // 會議模式按鈕前的間距
                         ],


                         // --- 開始計算/開始會議按鈕 (共用，文本不同) ---
                         ElevatedButton(
                           onPressed: _startCalculation, // 點擊時調用共用的啟動計算函數
                           style: ElevatedButton.styleFrom( // 按鈕樣式
                             padding: const EdgeInsets.symmetric(vertical: 15.0),
                             textStyle: const TextStyle(fontSize: 18),
                             shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(8.0),
                             ),
                           ),
                           // 按鈕文本根據模式顯示
                           child: Text(_meetingMode ? '開始會議計算' : '開始計算'),
                         ),
                         const SizedBox(height: 12), // 按鈕下方的間距
                         Text( // 顯示當前狀態或錯誤訊息
                           _statusMessage,
                           textAlign: TextAlign.center, // 文本居中
                           style: TextStyle(color: Colors.grey[600], fontSize: 14),
                         ),
                      ],

                      // --- 計算顯示界面 (根據模式和狀態條件顯示) ---
                      // 只有在正在計算/會議中/結束狀態時顯示這個界面
                      // 單人模式顯示條件：不在單人輸入狀態
                      // 會議模式顯示條件：不在會議輸入狀態
                      if ((!_meetingMode && (_isSingleWorking || _isSingleWorkdayFinished || _singleWorkStartTimeToday != null)) ||
                          (_meetingMode && (_isMeetingActive || _isMeetingEnded))) ...[

                         if (!_meetingMode) ...[ // --- 單人模式顯示 ---
                           Text( // 顯示暱稱
                              '${_singleNicknameController.text.trim()}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                           ),
                           const SizedBox(height: 16), // 間距

                           Text( // 顯示當前狀態訊息 (如 工作進行中 / 已達成)
                             _statusMessage,
                             textAlign: TextAlign.center,
                             style: TextStyle(
                                fontSize: _isSingleWorkdayFinished ? 20 : 16, // 完成時字體變大
                                fontWeight: _isSingleWorkdayFinished ? FontWeight.bold : FontWeight.normal, // 完成時加粗
                                color: _isSingleWorkdayFinished ? Colors.green : Colors.blueGrey, // 完成時變綠色
                             ),
                           ),
                            const SizedBox(height: 16), // 間距

                            // 時間進度條
                            ClipRRect( // 包裹 ClipRRect 以實現圓角
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: _singleWorkProgress, // 進度值 (0.0 to 1.0)
                                backgroundColor: Colors.grey[300], // 背景顏色
                                // 進度條顏色根據狀態改變
                                color: _isSingleWorking ? Colors.blueAccent : (_isSingleWorkdayFinished ? Colors.green : Colors.orange),
                                minHeight: 10, // 高度
                              ),
                            ),
                            const SizedBox(height: 8), // 間距
                            Text( // 顯示進度百分比 (可選)
                              '進度: ${(_singleWorkProgress * 100).toStringAsFixed(1)}%',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),

                            const SizedBox(height: 24), // 間距

                           Text( // 已賺金額提示文本
                             '您的努力為您賺到了:',
                             textAlign: TextAlign.center,
                             style: TextStyle(fontSize: 20, color: Colors.blueGrey[700]),
                           ),
                           Text( // 顯示實時計算的金額
                             '${_singleCurrentEarnings.toStringAsFixed(2)} 元', // 格式化金額，保留兩位小數
                             textAlign: TextAlign.center,
                             style: const TextStyle(
                               fontSize: 48, // 大字體顯示金額
                               fontWeight: FontWeight.bold, // 加粗
                               color: Colors.green, // 綠色顯示
                             ),
                           ),
                            const SizedBox(height: 24), // 間距

                         ],

                         if (_meetingMode) ...[ // --- 會議模式顯示 ---
                           Text( // 顯示當前狀態訊息 (會議進行中 / 已結束)
                             _statusMessage,
                             textAlign: TextAlign.center,
                             style: TextStyle(
                                fontSize: _isMeetingEnded ? 20 : 16, // 結束時字體變大
                                fontWeight: _isMeetingEnded ? FontWeight.bold : FontWeight.normal, // 結束時加粗
                                color: _isMeetingEnded ? Colors.green : Colors.blueGrey, // 結束時變綠色
                             ),
                           ),
                            const SizedBox(height: 24), // 間距

                           if (_isMeetingActive) ...[ // --- 會議進行中顯示 ---
                             // 使用 ListView.builder 顯示所有與會人員的實時收入列表
                             ListView.builder(
                                shrinkWrap: true, // 使列表適應內容高度
                                physics: const NeverScrollableScrollPhysics(), // 禁用內部滾動，讓外層 SingleChildScrollView 處理
                                itemCount: _meetingMembersData.length, // 列表項數量等於成員數據數量
                                itemBuilder: (context, index) {
                                  // 為每個成員構建一個顯示行 Widget
                                  return _buildMeetingMemberDisplayRow(_meetingMembersData[index]);
                                },
                             ),
                             const SizedBox(height: 24), // 間距
                             // "會議結束" 按鈕 (會議進行中時顯示)
                             ElevatedButton.icon(
                                onPressed: _endMeeting, // 點擊時結束會議
                                icon: const Icon(Icons.stop), // 圖標
                                label: const Text('會議結束'), // 文本
                                style: ElevatedButton.styleFrom( // 樣式
                                   backgroundColor: Colors.redAccent, // 紅色按鈕
                                   padding: const EdgeInsets.symmetric(vertical: 15.0),
                                   textStyle: const TextStyle(fontSize: 18),
                                   shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                   ),
                                ),
                             ),
                              const SizedBox(height: 24), // 間距
                           ],

                            if (_isMeetingEnded) ...[ // --- 會議已結束顯示 ---
                               // 會議總時長已經在狀態訊息中顯示
                               // 構建並顯示柱狀圖
                               if (_meetingMembersData.isNotEmpty) // 確保有數據才顯示圖表
                                 _buildBarChart(_meetingMembersData),
                                const SizedBox(height: 24), // 間距
                            ],
                         ],


                         // --- "回到設定頁" 按鈕 (共用，在計算/顯示界面始終顯示) ---
                         ElevatedButton(
                           onPressed: _reset, // 點擊時調用重置函數回到輸入界面
                           style: ElevatedButton.styleFrom( // 樣式
                             padding: const EdgeInsets.symmetric(vertical: 15.0),
                             textStyle: const TextStyle(fontSize: 18),
                             shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(8.0),
                             ),
                             backgroundColor: Colors.blueGrey, // 不同顏色
                           ),
                           child: const Text('回到設定頁'), // 按鈕文本
                         ),
                      ],
                    ],
                  ),
                );
              }
            ),
          ),
        ),
      ),
    );
  }
}