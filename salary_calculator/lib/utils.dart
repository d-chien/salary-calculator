// lib/utils.dart

import 'package:flutter/material.dart';
import 'dart:async'; // 需要用到 Timer (雖然這些函數沒有直接用，但放在一起管理工具類相關的可能需要)
import 'package:intl/intl.dart'; // 需要用到 DateFormat (雖然這些函數沒有直接用，但在 main 或其他頁面會用到)

// 根據月薪計算每秒費率 (假設每月工作 22 天，每天工作 8 小時)
double calculateSecondRate(double monthlySalary) { // 移除開頭的底線，使其成為公開函數
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

// 顯示時間選擇器並更新選中的開始時間
// 接收 BuildContext, 初始時間, 和一個回調函數來返回選擇的時間
Future<void> selectStartTime(BuildContext context, TimeOfDay? initialTime, ValueSetter<TimeOfDay?> onTimeSelected) async {
  final TimeOfDay? picked = await showTimePicker(
    context: context,
    initialTime: initialTime ?? TimeOfDay.now(),
  );
  onTimeSelected(picked); // 調用回調函數，將選擇的時間傳回給調用者
}

// 顯示時間選擇器並更新選中的結束時間
// 接收 BuildContext, 初始時間, 和一個回調函數來返回選擇的時間
Future<void> selectEndTime(BuildContext context, TimeOfDay? initialTime, ValueSetter<TimeOfDay?> onTimeSelected) async {
  final TimeOfDay? picked = await showTimePicker(
    context: context,
    initialTime: initialTime ?? TimeOfDay.now(),
  );
  onTimeSelected(picked); // 調用回調函數，將選擇的時間傳回給調用者
}

// 將 Duration 格式化為 H時 M分 S秒 的字串
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  return '${hours}時 ${minutes}分 ${seconds}秒';
}