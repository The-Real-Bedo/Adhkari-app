package com.adhkari.app

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// لازم نرث من AudioServiceActivity بدل FlutterActivity عشان الضغط على
// إشعار التلاوة يقدر يرجّع التطبيق للواجهة
class MainActivity : AudioServiceActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // قناة حفظ التلاوات في مكتبة الموسيقى بتاعة الجهاز.
        // بناخد applicationContext مش الـ Activity: الشغل بيكمّل على thread
        // تاني وممكن الشاشة تلف قبل ما النسخ يخلص.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AudioExport.CHANNEL,
        ).setMethodCallHandler(AudioExport(applicationContext))
    }
}
