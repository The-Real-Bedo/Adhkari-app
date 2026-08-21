package com.adhkari.app

import com.ryanheise.audioservice.AudioServiceActivity

// لازم نرث من AudioServiceActivity بدل FlutterActivity عشان الضغط على
// إشعار التلاوة يقدر يرجّع التطبيق للواجهة
class MainActivity : AudioServiceActivity()
