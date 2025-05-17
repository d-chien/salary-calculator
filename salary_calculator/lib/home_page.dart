// lib/home_page.dart

import 'package:flutter/material.dart';
import 'main.dart'; // 導入 main.dart 以使用 AdWidget

// <-- 確保這裡導入了其他頁面檔案，以便導航
import 'single_mode_page.dart';
import 'meeting_mode_page.dart';
import 'articles_page.dart';
import 'lunch_suggest_page.dart';


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text(
            '種下您今天的搖錢樹\nMake every second counts',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center( // 最外層的 Center，用於居中整個內容 Column
          child: Column( // 最外層的 Column，包含廣告和按鈕菜單
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch, // 保持 stretch，讓廣告可以全寬
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 20),

              // 第一個廣告
              const AdWidget(
                domId: 'div-onead-nd-01',
                viewType: 'onead-nd-view',
                uid: '2000493',
                playerMode: 'native-drive',
                positionId: '0',
              ),
              const SizedBox(height: 20),

              // 原有的按鈕菜單
              Center( // <--- 新增：在這裡包裹一個 Center 元件
                child: Container( // 按鈕菜單的 Container
                  constraints: const BoxConstraints(maxWidth: 400), // 這個 maxWidth 現在應該能正常生效
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SingleModePage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                          textStyle: const TextStyle(fontSize: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text('個人模式'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MeetingModePage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                          textStyle: const TextStyle(fontSize: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('會議模式'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ArticlesPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                          textStyle: const TextStyle(fontSize: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          backgroundColor: Colors.teal,
                        ),
                        child: const Text('文章專區'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LunchSuggestPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                          textStyle: const TextStyle(fontSize: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('午餐吃什麼？'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 第二個廣告
              const AdWidget(
                domId: 'div-onead-draft',
                viewType: 'onead-td-view',
                uid: '2000493',
                playerMode: 'text-drive',
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}