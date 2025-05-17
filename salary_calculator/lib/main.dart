// lib/main.dart
import 'dart:html' as html; // 導入為 html，避免名稱衝突
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:js_util'; // <-- 新增：導入 dart:js_util

// 確保這裡正確導入了你的 home_page.dart 檔案
import 'home_page.dart';

// 不再需要 _window 外部變數，將直接使用 html.window

// 註冊 Platform View Factory
// 這裡我們註冊兩個工廠，分別對應 Native Drive 和 Text Drive 廣告。
void registerOneAdView() {
  // 註冊 Native Drive 廣告的 DivElement 工廠
  ui.platformViewRegistry.registerViewFactory(
    'onead-nd-view', // 這個 viewType 會在 HtmlElementView 中使用
    (int viewId) => html.DivElement() // 使用 html.DivElement
      ..id = 'div-onead-nd-01' // 這是您原始 OneAD 腳本使用的 ID
      ..style.width = '100%'
      ..style.height = 'auto'
      ..style.zIndex = '9999' // 確保它在 Flutter 內容上方
      ..style.position = 'relative', // `position` 屬性是 `z-index` 生效的必要條件
  );

  // 註冊 Text Drive 廣告的 DivElement 工廠
  ui.platformViewRegistry.registerViewFactory(
    'onead-td-view', // 這個 viewType 會在 HtmlElementView 中使用
    (int viewId) => html.DivElement() // 使用 html.DivElement
      ..id = 'div-onead-draft' // 這是您原始 OneAD 腳本使用的 ID
      ..style.width = '100%'
      ..style.height = 'auto'
      ..style.zIndex = '9999'
      ..style.position = 'relative',
  );
}

void main() {
  // 在 runApp 之前註冊 Platform View 工廠
  registerOneAdView();
  runApp(const MyApp());
}

class AdWidget extends StatefulWidget {
  final String domId; // 這個 ID 將是廣告在 DOM 中實際的 ID (e.g., 'div-onead-nd-01')
  final String viewType; // 對應到 registerOneAdView 中註冊的 viewType
  final String uid; // OneAD 廣告的發布商 ID
  final String playerMode; // 廣告播放模式 (e.g., "native-drive", "text-drive")
  final String? positionId; // 針對 Native Drive 廣告的選用參數

  const AdWidget({
    super.key,
    required this.domId,
    required this.viewType,
    required this.uid,
    required this.playerMode,
    this.positionId,
  });

  @override
  State<AdWidget> createState() => _AdWidgetState();
}

class _AdWidgetState extends State<AdWidget> {
  @override
  void initState() {
    super.initState();
    // 在 Widgets 渲染完成後（下一幀）執行載入廣告的邏輯，確保 DivElement 已在 DOM 中
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOneAd();
    });
  }

  // 載入並初始化 OneAD 廣告
  void _loadOneAd() {
    // 引入一個短暫的延遲，確保 HTML 元素完全渲染到 DOM 中
    Future.delayed(const Duration(milliseconds: 50), () { // 嘗試 50 毫秒的延遲
      final html.DivElement? adDiv = html.document.getElementById(widget.domId) as html.DivElement?;

      if (adDiv == null) {
        print('OneAD: Div element with ID ${widget.domId} still not found after delay. This might indicate a problem with the ID or rendering.');
        // 如果延遲後仍然找不到，可能需要進一步檢查 ID 或渲染邏輯
        return;
      }

      print('OneAD: Found div element: ${widget.domId}');

      final customCall = allowInterop((params) {
        if (params.hasAd) {
          print('OneAD Slot (${widget.domId}) has AD.');
        } else {
          print('OneAD Slot (${widget.domId}) AD Empty.');
        }
      });

      final Map<String, dynamic> oneadTextPub = {
        'uid': widget.uid,
        'slotobj': adDiv,
        'player_mode': widget.playerMode,
        'queryAdCallback': customCall,
      };

      if (widget.playerMode == "native-drive") {
        oneadTextPub['player_mode_div'] = "div-onead-ad";
        oneadTextPub['max_threads'] = 3;
        oneadTextPub['position_id'] = widget.positionId ?? "0";
      }

      final jsOneadText = jsify({'pub': oneadTextPub});

      dynamic oneadTextPubs = getProperty(html.window, 'ONEAD_text_pubs');

      if (oneadTextPubs == null) {
        oneadTextPubs = jsify([]);
        setProperty(html.window, 'ONEAD_text_pubs', oneadTextPubs);
      }

      callMethod(oneadTextPubs, 'push', [jsOneadText]);

      print('OneAD: Pushed config for ${widget.domId}.');
    }); // Future.delayed 結束
  }


  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: 250, // 設置一個合理的預設高度，確保廣告有足夠的空間渲染
      child: HtmlElementView(viewType: widget.viewType),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '薪水計算器',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.blueGrey[60],
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: false,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}