// lib/main.dart

import 'package:flutter/material.dart';
// <-- 確保這裡正確導入了你的 home_page.dart 檔案
import 'home_page.dart';


void main() {
  // Flutter 應用程式的入口點
  // runApp 函數會接收並執行你的應用程式根 Widget (通常是 MyApp)
  runApp(const MyApp());
}

// MyApp 是應用程式的根 Widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp 提供了應用程式的基本設定和 Material Design 主題
    return MaterialApp(
      // 應用程式的系統級標題，顯示在多工切換、瀏覽器分頁等地方
      title: '薪水計算器', // 保持一個簡潔的系統標題
      // 應用程式的主題設定
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.blueGrey[60],
        primarySwatch: Colors.blue, // 使用 Material Design 的藍色主題
        visualDensity: VisualDensity.adaptivePlatformDensity, // 視覺密度，適應不同平台
        //useMaterial3: true
      ),
      // 移除右上角的 debug 標誌 (發布時通常會移除)
      debugShowCheckedModeBanner: false,
      // 設定應用程式啟動後顯示的第一個頁面
      // 這裡將 HomePage 設定為應用程式的初始畫面
      home: const HomePage(), // <-- 設定你的 HomePage 為啟動頁面
    );
  }
}
