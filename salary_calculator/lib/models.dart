// lib/models.dart

import 'package:flutter/material.dart'; // 需要用到 TextEditingController

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
  double currentEarnings; // 會議進行中時或結束時，該成員的累積/總收入

  MeetingMemberData({
    required this.nickname,
    required this.monthlySalary,
    required this.secondRate,
    this.currentEarnings = 0.0,
  });
}

// 用於圖表的資料類別 (適用於柱狀圖和圓環圖)
class SalaryCost {
  final String member; // 與會人員暱稱 (圖表的域 Domain)
  final double cost; // 會議結束時，該人員的總薪水花費 (圖表的度量 Measure)

  SalaryCost(this.member, this.cost);
}