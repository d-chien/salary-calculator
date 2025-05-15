// lib/home_page.dart

import 'package:flutter/material.dart';
// <-- 導入其他頁面檔案，以便導航
import 'single_mode_page.dart';
import 'meeting_mode_page.dart';
import 'articles_page.dart';
import 'lunch_suggest_page.dart';


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold 提供了頁面基本結構
    return Scaffold(
      appBar: AppBar( // 頁面的頂部欄
        // 主選單頁面的標題，使用之前討論過的雙行標題和填充
        title: const Padding( // 使用 Padding 添加頂部填充
          padding: EdgeInsets.only(top: 8.0),
          child: Text( // 標題文字，會根據空間換行
            '種下您今天的搖錢樹\nMake every second counts',
            style: TextStyle(fontSize: 16), // 設定字體大小
            textAlign: TextAlign.center, // 文字內容置中對齊
          ),
        ),
        centerTitle: true, // AppBar 中的標題 Widget 整體置中
      ),
      body: Center( // 將主要內容置中
        child: Container( // 限制最大寬度並添加樣式
           constraints: const BoxConstraints(maxWidth: 400), // 限制選單容器的最大寬度
           padding: const EdgeInsets.all(16.0), // 內部填充
            decoration: BoxDecoration( // 添加樣式 (背景色, 圓角, 陰影)
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
           child: Column( // 垂直排列選單按鈕
              mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
              crossAxisAlignment: CrossAxisAlignment.stretch, // 水平拉伸
              mainAxisSize: MainAxisSize.min, // Column 高度適應內容
              children: <Widget>[
                // --- 選單按鈕 ---

                // 個人模式按鈕
                ElevatedButton(
                  onPressed: () {
                    // 使用 Navigator.push 導航到 SingleModePage
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SingleModePage()), // 創建並導航到單人模式頁面
                    );
                  },
                   style: ElevatedButton.styleFrom( // 按鈕樣式
                     padding: const EdgeInsets.symmetric(vertical: 15.0),
                     textStyle: const TextStyle(fontSize: 18),
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(8.0),
                     ),
                   ),
                  child: const Text('個人模式'), // 按鈕文字
                ),
                const SizedBox(height: 16), // 間距

                // 會議模式按鈕
                ElevatedButton(
                   onPressed: () {
                     // 使用 Navigator.push 導航到 MeetingModePage
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MeetingModePage()), // 創建並導航到會議模式頁面
                    );
                  },
                   style: ElevatedButton.styleFrom( // 按鈕樣式 (不同顏色)
                     padding: const EdgeInsets.symmetric(vertical: 15.0),
                     textStyle: const TextStyle(fontSize: 18),
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(8.0),
                     ),
                     backgroundColor: Colors.green,
                   ),
                  child: const Text('會議模式'), // 按鈕文字
                ),
                 const SizedBox(height: 16), // 間距

                 // 文章專區按鈕
                 ElevatedButton(
                   onPressed: () {
                     // 使用 Navigator.push 導航到 ArticlesPage
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ArticlesPage()), // 創建並導航到文章專區頁面
                    );
                  },
                   style: ElevatedButton.styleFrom( // 按鈕樣式 (不同顏色)
                     padding: const EdgeInsets.symmetric(vertical: 15.0),
                     textStyle: const TextStyle(fontSize: 18),
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(8.0),
                     ),
                      backgroundColor: Colors.teal,
                   ),
                  child: const Text('文章專區'), // 按鈕文字
                ),
                const SizedBox(height: 16), // 間距
                
                // <-- 新增：午餐建議按鈕 -->
                 ElevatedButton(
                   onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LunchSuggestPage()), // 導航到午餐建議頁面
                    );
                  },
                   style: ElevatedButton.styleFrom( // 按鈕樣式 (不同顏色)
                     padding: const EdgeInsets.symmetric(vertical: 15.0),
                     textStyle: const TextStyle(fontSize: 18),
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(8.0),
                     ),
                      backgroundColor: Colors.orange, // 橘色按鈕
                   ),
                  child: const Text('午餐吃什麼？'), // 按鈕文字
                ),
                // <-- 新增按鈕結束 -->
              ],
           ),
        ),
      ),
    );
  }
}