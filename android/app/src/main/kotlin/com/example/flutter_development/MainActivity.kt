package com.example.flutter_development

import com.ryanheise.audioservice.AudioServiceActivity

// لازم نرث من AudioServiceActivity بدل FlutterActivity عشان الضغط على
// إشعار التلاوة يقدر يرجّع التطبيق للواجهة
class MainActivity : AudioServiceActivity()
