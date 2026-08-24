package com.adhkari.app

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * حفظ التلاوة المحمّلة في مكتبة الموسيقى بتاعة الجهاز.
 *
 * التطبيق بينزّل التلاوات في مجلده الخاص، وده مقصود: مفيش صلاحية تخزين
 * مطلوبة والملفات بتتمسح مع التطبيق. بس المجلد الخاص ده مالوش وجود عند أي
 * مشغل تاني على الجهاز، فالمستخدم مش بيلاقي التلاوة في مشغل الموسيقى
 * بتاعه. الكلاس ده بينسخ الملف لمكتبة الموسيقى العامة.
 *
 * **ليه MediaStore ومش نسخ ملف عادي:** مشغلات الموسيقى بتقرا من فهرس
 * MediaStore مش من الملفات نفسها، والفهرس بيتبني من الأعمدة اللي إحنا
 * بنكتبها هنا — مش من وسوم ID3 اللي جوه الـ mp3. ملفات mp3quran.net
 * وسومها ناقصة أو فاضية، فنسخ الملف زي ما هو كان هيظهر باسم زي
 * `r7_m1_s002` ومن غير قارئ. عشان كده بنكتب TITLE و ARTIST و ALBUM
 * و TRACK بأيدينا.
 *
 * **الصلاحيات:** على API 29 وفوق الكتابة في MediaStore بمسار RELATIVE_PATH
 * مبتطلبش أي صلاحية تخزين خالص — التطبيق بيكتب في مساحته من المجلد العام.
 * عشان كده الـ minSdk اتظبط على 29.
 */
class AudioExport(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.adhkari.app/audio_export"

        /** المجلد جوه Music/ اللي التلاوات بتتحفظ فيه */
        private const val FOLDER = "أذكاري"

        private const val MIME = "audio/mpeg"
    }

    private val relativePath = "${Environment.DIRECTORY_MUSIC}/$FOLDER"

    /**
     * MediaStore بيخزّن RELATIVE_PATH وهو منتهي بشرطة مايلة، فلازم نسأل
     * بنفس الشكل وإلا الاستعلام مايلاقيش حاجة.
     */
    private val storedPath = "$relativePath/"

    private val mainHandler = Handler(Looper.getMainLooper())

    private val collection: Uri
        get() = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "export" -> handleExport(call, result)

            "isExported" -> {
                val fileName = call.argument<String>("fileName")
                if (fileName == null) {
                    result.error("bad_args", "fileName مطلوب", null)
                } else {
                    runOffMainThread(result) {
                        mapOf("exported" to (findExisting(fileName) != null))
                    }
                }
            }

            "folder" -> result.success(relativePath)

            else -> result.notImplemented()
        }
    }

    private fun handleExport(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        val fileName = call.argument<String>("fileName")

        if (sourcePath == null || fileName == null) {
            result.error("bad_args", "sourcePath و fileName مطلوبين", null)
            return
        }

        val title = call.argument<String>("title") ?: fileName
        val artist = call.argument<String>("artist")
        val album = call.argument<String>("album")
        val track = call.argument<Int>("track")

        runOffMainThread(result) {
            export(sourcePath, fileName, title, artist, album, track)
        }
    }

    private fun export(
        sourcePath: String,
        fileName: String,
        title: String,
        artist: String?,
        album: String?,
        track: Int?,
    ): Map<String, Any?> {
        val source = File(sourcePath)
        if (!source.isFile) {
            throw IllegalStateException("الملف الأصلي مش موجود")
        }

        // موجود قبل كده؟ مانعملش نسخة تانية — المستخدم ممكن يدوس الزرار
        // مرتين، وتلاوة مكرّرة في مشغل الموسيقى حاجة مزعجة.
        findExisting(fileName)?.let { existing ->
            return mapOf(
                "uri" to existing.toString(),
                "folder" to relativePath,
                "existed" to true,
            )
        }

        val resolver = context.contentResolver

        val values = metadataValues(title, artist, album, track).apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Audio.Media.MIME_TYPE, MIME)
            put(MediaStore.Audio.Media.RELATIVE_PATH, relativePath)
            put(MediaStore.Audio.Media.IS_MUSIC, 1)

            // IS_PENDING بتخفي الصف عن باقي التطبيقات لحد ما النسخ يخلص،
            // فمشغل الموسيقى مايشوفش ملف نص مكتوب.
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }

        val uri: Uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("MediaStore رفض إنشاء الملف")

        try {
            val output = resolver.openOutputStream(uri)
                ?: throw IllegalStateException("مش قادرين نفتح الملف للكتابة")

            output.use { out ->
                source.inputStream().use { input -> input.copyTo(out) }
            }
        } catch (e: Exception) {
            // لو النسخ وقع في نصه بنشيل الصف المعلّق، وإلا بيفضل محجوز
            // ومخفي على الجهاز للأبد.
            runCatching { resolver.delete(uri, null, null) }
            throw e
        }

        val done = ContentValues()
        done.put(MediaStore.Audio.Media.IS_PENDING, 0)
        resolver.update(uri, done, null, null)

        // أول ما IS_PENDING تبقى صفر، MediaProvider بيفحص الملف وبيعيد بناء
        // الأعمدة من وسوم الـ mp3 نفسها — واللي بتشيل الأسماء اللي كتبناها
        // فوق. عشان كده بنكتبهم تاني بعد الفحص. لو الخطوة دي فشلت الملف
        // نفسه يفضل سليم ومحفوظ، فمابنوقّعش التصدير بسببها؛ أسوأ حالة إن
        // المشغل يعرض اسم الملف — وهو مقروء بالعربي أصلًا.
        runCatching {
            resolver.update(
                uri,
                metadataValues(title, artist, album, track),
                null,
                null,
            )
        }

        return mapOf(
            "uri" to uri.toString(),
            "folder" to relativePath,
            "existed" to false,
        )
    }

    /**
     * الأعمدة اللي بتظهر للمستخدم في مشغل الموسيقى.
     *
     * منفصلة في دالة لأنها بتتكتب مرتين: مرة مع الإنشاء، ومرة بعد فحص
     * MediaProvider اللي بيدوس عليها.
     */
    private fun metadataValues(
        title: String,
        artist: String?,
        album: String?,
        track: Int?,
    ): ContentValues = ContentValues().apply {
        put(MediaStore.Audio.Media.TITLE, title)
        artist?.let { put(MediaStore.Audio.Media.ARTIST, it) }
        album?.let { put(MediaStore.Audio.Media.ALBUM, it) }
        // رقم السورة بيخلّي المشغل يرتّبهم بترتيب المصحف
        track?.let { put(MediaStore.Audio.Media.TRACK, it) }
    }

    /** بيرجّع URI الملف لو محفوظ قبل كده في نفس المجلد وبنفس الاسم */
    private fun findExisting(fileName: String): Uri? {
        context.contentResolver.query(
            collection,
            arrayOf(MediaStore.Audio.Media._ID),
            "${MediaStore.Audio.Media.RELATIVE_PATH}=? AND " +
                "${MediaStore.Audio.Media.DISPLAY_NAME}=?",
            arrayOf(storedPath, fileName),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                // ContentUris مش getContentUri(volume, id): الأوفرلود اللي
                // بياخد id مضاف في API 30 والـ minSdk عندنا 29.
                return ContentUris.withAppendedId(collection, cursor.getLong(0))
            }
        }
        return null
    }

    /**
     * نسخ ملف بحجم ٥ ميجا على الـ main thread بيجمّد الواجهة، فالشغل بيتم
     * على thread لوحده. الرد لازم يرجع على الـ main thread — ده شرط في
     * MethodChannel.
     *
     * Thread عادي مش coroutine عن قصد: الوحدة دي محتاجة تشتغل من غير ما
     * نضيف kotlinx-coroutines لملف الـ Gradle.
     */
    private fun runOffMainThread(
        result: MethodChannel.Result,
        work: () -> Map<String, Any?>,
    ) {
        Thread {
            try {
                val value = work()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("export_failed", e.message, null)
                }
            }
        }.start()
    }
}
