import 'package:flutter/material.dart';

// 這個 Widget 用於顯示文章列表或單篇文章內容
class ArticlesPage extends StatelessWidget {
  // 構造函數，使用 Key 是 Flutter 的最佳實踐
  const ArticlesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold 提供了應用程式的基本結構，如頂部欄和內容區域
    return Scaffold(
      appBar: AppBar(
        title: const Text('文章專區'), // 文章頁面的標題
        centerTitle: true, // 標題置中
      ),
      // Body 內容區域，使用 SingleChildScrollView 包裹以確保內容可滾動
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0), // 內容區域的內邊距
        // 使用 Column 將文章標題和內容垂直排列
        child: Column(
          // 將 Column 的子元件靠左對齊 (對於文字內容很自然)
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // --- 文章標題和內容範例 ---

            // 文章一
            Text(
              '如何有效談判薪資？', // 文章標題
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8), // 標題與內容之間的間距
            Text(
              '薪資談判是職業生涯中重要的一環。準備充分、了解市場價值是關鍵。研究同行業、同職位在您所在地區的平均薪資水平。在談判時，自信但保持彈性，強調您的技能和能為公司帶來的價值。記住，薪資不僅僅是底薪，還包括獎金、福利、帶薪休假等。\n\n此外，了解公司的薪資結構和預算也能幫助您更好地談判。不要害怕提出您的期望，但也準備好討論和妥協。一個成功的薪資談判能顯著影響您的長期財務狀況。', // 文章內容 (請替換為你實際的內容)
              style: TextStyle(fontSize: 16),
            ),
            Divider(height: 32, thickness: 1), // 文章之間的分隔線

            // 文章二
            Text(
              '會議成本計算與節省技巧', // 文章標題
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8), // 標題與內容之間的間距
            Text(
              '每次會議都在消耗參與者的時間和公司的薪資。利用我們的會議成本計算器，您可以清楚看到每次會議的實際花費。為了降低成本，請確保會議有明確的議程、控制好時間、並只邀請必要的人員。提前分發會議資料，讓與會者能先了解主題。\n\n鼓勵在會議結束後立即行動，並記錄關鍵決策和待辦事項。考慮使用其他溝通方式（如郵件、即時通訊）來替代非必要的會議。提升會議效率不僅節省金錢，也能提高團隊的生產力。', // 文章內容 (請替換為你實際的內容)
              style: TextStyle(fontSize: 16),
            ),
            Divider(height: 32, thickness: 1), // 分隔線

            // 文章二
            Text(
              '有效善用工作時間的技巧', // 文章標題
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8), // 標題與內容之間的間距
            Text(
              '是不是覺得，每天工作似乎都一成不變，永遠有忙的事情要做，永遠都做不完？給你一個小技巧，當你工作漫無目的的時候，停下來思考一下，我現在在做的事情真的值得我花這樣的時間做嗎？還是我其實可以有更有效率的方式進行？',
              style: TextStyle(fontSize: 16),
            ),
            Divider(height: 32, thickness: 1), // 分隔線

            // 你可以在這裡添加更多文章...
             Text(
              '夢想儲蓄計劃：將目標變為現實', // 文章標題
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8), // 標題與內容之間的間距
            Text(
              '設定一個明確的財務目標（例如買房、旅行、退休）是實現夢想的第一步。利用我們的薪水計算器，您可以追蹤您的收入。接下來，制定儲蓄計劃：確定每月能儲存多少金額，並考慮將這筆錢進行投資以加速財富增長。分散風險、定期定額投資是常見的策略。\n\n檢視您的開銷，找出可以節省的地方。將省下的錢投入您的夢想儲蓄帳戶。定期回顧您的進度，並在需要時調整計劃。記住，每一個小小的儲蓄步驟，都在幫助您更接近您的夢想。', // 文章內容 (請替換為你實際的內容)
              style: TextStyle(fontSize: 16),
            ),
            // 添加更多文章...

          ],
        ),
      ),
    );
  }
}