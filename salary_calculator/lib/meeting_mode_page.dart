// lib/meeting_mode_page.dart

import 'package:flutter/material.dart';
import 'dart:async'; // 用於 Timer
import 'dart:math'; // 用於 min
import 'package:intl/intl.dart'; // 用於時間格式化
import 'package:community_charts_flutter/community_charts_flutter.dart' as charts; // 用於繪製圖表 (使用 community 版本)

import 'models.dart'; // <-- 導入資料模型
import 'utils.dart'; // <-- 導入工具函數


class MeetingModePage extends StatefulWidget {
  const MeetingModePage({super.key});

  @override
  State<MeetingModePage> createState() => _MeetingModePageState();
}

class _MeetingModePageState extends State<MeetingModePage> {
  // --- 會議模式狀態變數 ---
  // 這些狀態變數只與會議模式相關，所以放在這裡
  String _statusMessage = '輸入與會人員資訊，然後點擊開始會議';
  Timer? _timer; // 會議模式自己的定時器

  List<MeetingMemberInput> _meetingMembersInput = []; // 會議成員輸入控制器列表
  List<MeetingMemberData> _meetingMembersData = []; // 會議成員計算數據列表

  DateTime? _meetingStartTime; // 會議開始時間
  DateTime? _meetingEndTime; // 會議結束時間
  Duration? _meetingDuration; // 會議總時長

  bool _isMeetingActive = false; // 會議是否進行中
  bool _isMeetingEnded = false; // 會議是否已結束

  final int _minMeetingMembers = 1; // 最少成員數
  final int _maxMeetingMembers = 20; // 最多成員數

  // 保留選擇的會議開始時間，即使重置會議，用戶可能想沿用上次的時間
  TimeOfDay? _selectedStartTime; // 會議開始時間輸入 (保留)

  // --- 初始化狀態 ---
  @override
  void initState() {
    super.initState();
    // 初始化會議成員輸入框為預設數量
    _initializeMeetingMembersInput(_minMeetingMembers);
  }

  // --- 資源清理 ---
  @override
  void dispose() {
    // 清理成員輸入控制器和定時器
    for (var memberInput in _meetingMembersInput) {
      memberInput.dispose();
    }
    _timer?.cancel(); // 離開頁面時取消定時器
    super.dispose();
  }

  // --- 會議模式邏輯 ---
  // 初始化/重新初始化會議成員輸入框控制器列表
  void _initializeMeetingMembersInput(int count) {
    count = min(count, _maxMeetingMembers);
    for (int i = 0; i < count; i++) {
      _meetingMembersInput.add(MeetingMemberInput(
        nicknameController: TextEditingController(),
        salaryController: TextEditingController(),
      ));
    }
  }

  // 添加與會人員輸入框
  void _addMeetingMemberInput() {
    if (_meetingMembersInput.length < _maxMeetingMembers) {
      setState(() {
        _meetingMembersInput.add(MeetingMemberInput(
          nicknameController: TextEditingController(),
          salaryController: TextEditingController(),
        ));
      });
    } else {
       // 達到上限時顯示提示
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('最多只能添加 20 位與會人員')),
       );
    }
  }

  // 啟動會議計算
  void _startMeetingCalculation() { // 函數名稱更改為更具體
    _timer?.cancel(); // 啟動前取消舊定時器

    // 驗證會議開始時間是否已選
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

      // 計算該成員的每秒費率 (使用 utils 裡的函數)
      final secondRate = calculateSecondRate(monthlySalary);

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

    // 驗證都通過，初始化會議狀態
    _meetingMembersData = membersData;
    _meetingStartTime = DateTime.now(); // 記錄精確開始時間
    _meetingEndTime = null; // 結束時才設定
    _meetingDuration = null; // 結束時才計算

    _isMeetingActive = true; // 設定為進行中
    _isMeetingEnded = false; // 設定為未結束

    setState(() { _statusMessage = '會議進行中...'; }); // 設定狀態訊息

    // 啟動定時器，定時更新會議顯示 (使用 community_charts_flutter)
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _updateMeetingDisplay(); // 定時調用更新顯示 (函數名稱更改為更具體)
    });

    // 立即更新一次顯示
    _updateMeetingDisplay();
  }

  // 更新會議顯示 (成員實時收入，會議持續時間)
  void _updateMeetingDisplay() { // 函數名稱更改為更具體
    final currentTime = DateTime.now(); // 獲取當前時間

    // 如果會議不是進行中或已經結束，則不做任何事
    if (!_isMeetingActive || _meetingStartTime == null || _isMeetingEnded) {
       _timer?.cancel(); // 再次確保計時器被取消
       return; // 保持狀態不變
    }

    // 計算從會議開始到當前的總經過時間
    final elapsedDuration = currentTime.difference(_meetingStartTime!);
    final elapsedSeconds = elapsedDuration.inSeconds.toDouble(); // 轉換為秒數

    if (elapsedSeconds < 0) { // 時間錯誤處理
        setState(() { _statusMessage = '時間錯誤'; _isMeetingActive = false; });
         _timer?.cancel();
         return;
    }

    // 更新每一個與會人員的實時累積收入
    setState(() {
       for (var memberData in _meetingMembersData) {
         memberData.currentEarnings = elapsedSeconds * memberData.secondRate;
       }

       // 更新狀態訊息顯示會議持續時間 (使用 utils 裡的函數)
       _statusMessage = '會議進行中... 已持續 ${formatDuration(elapsedDuration)}';
    });
  }

  // 結束會議
  void _endMeeting() {
    // 只有在會議進行中且開始時間已設定時，才能結束會議
    if (_isMeetingActive && _meetingStartTime != null) {
      _timer?.cancel(); // 停止定時器

      final endTime = DateTime.now(); // 記錄結束時間
      final duration = endTime.difference(_meetingStartTime!); // 計算總時長

      // 根據精確的總時長，重新計算每個成員的最終收入
       for (var memberData in _meetingMembersData) {
           memberData.currentEarnings = duration.inSeconds.toDouble() * memberData.secondRate;
       }

      // 更新狀態，顯示會議結束畫面
      setState(() {
        _meetingEndTime = endTime; // 設定結束時間
        _meetingDuration = duration; // 設定總時長

        _isMeetingActive = false; // 設定為非進行中
        _isMeetingEnded = true; // 設定為已結束

        // 更新狀態訊息顯示最終總時長 (使用 utils 裡的函數)
        _statusMessage = '會議已結束！總時長 ${formatDuration(duration)}';
      });
    }
  }

  // 重置會議模式狀態
  void _resetMeeting() { // 函數名稱更改為更具體
     _timer?.cancel(); // 取消定時器

     setState(() {
       // 銷毀並清空舊的成員輸入控制器列表
       for(var memberInput in _meetingMembersInput) {
         memberInput.dispose();
       }
       _meetingMembersInput.clear();

       // 重新初始化預設數量的成員輸入控制器列表
       _initializeMeetingMembersInput(_minMeetingMembers);

       _meetingMembersData.clear(); // 清空成員數據列表
       _meetingStartTime = null; // 重置時間和時長
       _meetingEndTime = null;
       _meetingDuration = null;

       _isMeetingActive = false; // 重置狀態
       _isMeetingEnded = false;

       _statusMessage = '輸入與會人員資訊，然後點擊開始會議'; // 重設狀態訊息
       // 保留 _selectedStartTime 的值 (如果用戶想為下次會議保留開始時間選擇)
     });
  }

  // 構建單個會議成員的輸入行 (獨立函數，方便在 build 中調用)
  Widget _buildMeetingMemberInputRow(MeetingMemberInput memberInput, int index) {
    return Card( // 使用 Card 包裹，提供視覺分隔
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // 文本靠左對齊
          children: [
             // 顯示成員編號
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
              keyboardType: TextInputType.numberWithOptions(decimal: true, signed: false), // 數字鍵盤
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

  // 構建單個會議成員的顯示行 (獨立函數，方便在 build 中調用)
  Widget _buildMeetingMemberDisplayRow(MeetingMemberData memberData) {
      // 使用 ListTile 呈現更清晰的列表項
      return ListTile(
        leading: CircleAvatar( // 左側圓形頭像/圖標
          backgroundColor: Colors.blueAccent,
          // 顯示暱稱的第一個字母
          child: Text(memberData.nickname.isNotEmpty ? memberData.nickname[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white)),
        ),
        title: Text(memberData.nickname), // 顯示暱稱
        // trailing 顯示該成員當前賺到的金額
        trailing: Text('${memberData.currentEarnings.toStringAsFixed(2)} 元',
             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        // subtitle 顯示原始月薪 (可選)
        subtitle: Text('月薪: ${memberData.monthlySalary.toStringAsFixed(0)}'),
      );
  }

  // 構建柱狀圖 (在會議模式結束後顯示) - 獨立函數，方便在 build 中調用
  Widget _buildBarChart(List<MeetingMemberData> membersData) {
    // 準備圖表數據 (SalaryCost 是圖表需要的格式)
    final List<SalaryCost> data = membersData.map((member) => SalaryCost(member.nickname, member.currentEarnings)).toList();

    // 如果沒有數據或所有金額為零，不顯示圖表
     if (data.isEmpty || data.every((cost) => cost.cost == 0)) {
        return const SizedBox.shrink(); // 返回空 Widget
     }

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

     // 將圖表包裹在 Container 中控制大小
     return Container(
        height: min(300.0, membersData.length * 60.0 + 50.0), // 動態調整高度
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: chart, // 顯示圖表
     );
  }


  // --- 構建 UI ---
  @override
  Widget build(BuildContext context) {
    // 判斷是否顯示輸入表單 (未進行中且未結束時顯示)
    bool showInputForm = !_isMeetingActive && !_isMeetingEnded;

    return Scaffold(
      appBar: AppBar(
        title: const Text('會議模式'), // 頁面標題
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
                       '設定你的會議',
                       textAlign: TextAlign.center,
                       style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                     ),
                     const SizedBox(height: 24),

                     // 會議開始時間選擇器 (使用 utils 裡的函數)
                     Row(
                       children: [
                         Expanded(
                           child: ElevatedButton.icon(
                             // 點擊時調用時間選擇器並更新狀態
                             onPressed: () => selectStartTime(context, _selectedStartTime, (time) {
                               setState(() { _selectedStartTime = time; });
                             }),
                             icon: const Icon(Icons.access_time),
                             label: const Text('選擇會議開始時間'),
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

                     // 會議成員輸入列表 (使用 ListView.builder 和 _buildMeetingMemberInputRow)
                     ListView.builder(
                        shrinkWrap: true, // 列表高度適應內容
                        physics: const NeverScrollableScrollPhysics(), // 禁用列表自身的滾動
                        itemCount: _meetingMembersInput.length, // 列表項數量
                        itemBuilder: (context, index) {
                           return _buildMeetingMemberInputRow(_meetingMembersInput[index], index); // 構建輸入行
                        },
                     ),
                     const SizedBox(height: 8),

                     // 添加成員按鈕
                     if (_meetingMembersInput.length < _maxMeetingMembers) // 達到上限時隱藏按鈕
                        ElevatedButton.icon(
                          onPressed: _addMeetingMemberInput, // 點擊時添加成員
                          icon: const Icon(Icons.add), // 圖標
                          label: Text('添加與會人員 (${_meetingMembersInput.length}/${_maxMeetingMembers})'), // 按鈕文字顯示當前數量
                          style: ElevatedButton.styleFrom( // 按鈕樣式
                             backgroundColor: Colors.green,
                             padding: const EdgeInsets.symmetric(vertical: 12.0),
                             textStyle: const TextStyle(fontSize: 16),
                             shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                             ),
                          ),
                        ),
                     const SizedBox(height: 24), // 間距

                     // --- 開始會議按鈕 ---
                     ElevatedButton(
                       onPressed: _startMeetingCalculation, // 點擊時啟動會議計算
                       style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 15.0),
                         textStyle: const TextStyle(fontSize: 18),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(8.0),
                         ),
                       ),
                       child: const Text('開始會議計算'), // 按鈕文字
                     ),
                     const SizedBox(height: 12), // 間距
                     Text( // 顯示狀態訊息
                       _statusMessage,
                       textAlign: TextAlign.center,
                       style: TextStyle(color: Colors.grey[600], fontSize: 14),
                     ),
                   ],

                   // --- 計算顯示區塊 ---
                   if (!showInputForm) ...[ // 當不顯示輸入表單時 (進行中或已結束)
                      // 顯示狀態訊息 (會議進行中或已結束)
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                           fontSize: _isMeetingEnded ? 20 : 16,
                           fontWeight: _isMeetingEnded ? FontWeight.bold : FontWeight.normal,
                           color: _isMeetingEnded ? Colors.green : Colors.blueGrey,
                        ),
                      ),
                       const SizedBox(height: 24), // 間距

                      if (_isMeetingActive) ...[ // --- 會議進行中顯示 ---
                        // 顯示與會人員實時收入列表 (使用 ListView.builder 和 _buildMeetingMemberDisplayRow)
                        ListView.builder(
                           shrinkWrap: true, // 列表高度適應內容
                           physics: const NeverScrollableScrollPhysics(), // 禁用列表自身的滾動
                           itemCount: _meetingMembersData.length, // 列表項數量
                           itemBuilder: (context, index) {
                             return _buildMeetingMemberDisplayRow(_meetingMembersData[index]); // 構建顯示行
                           },
                        ),
                        const SizedBox(height: 24), // 間距
                        // "會議結束" 按鈕 (會議進行中時顯示)
                        ElevatedButton.icon(
                          onPressed: _endMeeting, // 點擊時結束會議
                          icon: const Icon(Icons.stop), // 圖標
                          label: const Text('會議結束'), // 文本
                          style: ElevatedButton.styleFrom( // 樣式
                             backgroundColor: Colors.redAccent,
                             padding: const EdgeInsets.symmetric(vertical: 15.0),
                             textStyle: const TextStyle(fontSize: 18),
                             shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                             ),
                          ),
                        ),
                         const SizedBox(height: 24), // 間距
                      ],

                       if (_isMeetingEnded) ...[ // --- 會議已結束顯示 (顯示柱狀圖) ---
                          if (_meetingMembersData.isNotEmpty) // 確保有數據才構建圖表
                            _buildBarChart(_meetingMembersData), // 構建柱狀圖
                          const SizedBox(height: 24), // 間距
                       ],

                      // --- 回到設定頁按鈕 ---
                      ElevatedButton(
                        onPressed: _resetMeeting, // 點擊時重置會議狀態
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                          textStyle: const TextStyle(fontSize: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          backgroundColor: Colors.blueGrey, // 灰色按鈕
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