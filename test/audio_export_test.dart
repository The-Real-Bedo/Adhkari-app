import 'package:adhkari/services/audio_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioExportService.exportFileName', () {
    test('بيطلّع اسم مقروء برقم السورة والقارئ', () {
      expect(
        AudioExportService.exportFileName(
          surahId: 2,
          surahName: 'البقرة',
          reciterName: 'عبد الباسط عبد الصمد',
        ),
        '002 - البقرة - عبد الباسط عبد الصمد.mp3',
      );
    });

    test('الرقم بيتكمّل لتلات خانات عشان الترتيب الأبجدي يطابق المصحف', () {
      final first = AudioExportService.exportFileName(
        surahId: 1,
        surahName: 'الفاتحة',
        reciterName: 'قارئ',
      );
      final last = AudioExportService.exportFileName(
        surahId: 114,
        surahName: 'الناس',
        reciterName: 'قارئ',
      );

      expect(first, startsWith('001 '));
      expect(last, startsWith('114 '));
      // من غير التكميل ده "114" كانت هتيجي قبل "2" في أي تطبيق ملفات
      expect(first.compareTo(last) < 0, isTrue);
    });

    test('بيشيل الشرطة المايلة — MediaStore بيرفض الصف كله لو لقاها', () {
      final name = AudioExportService.exportFileName(
        surahId: 6,
        surahName: 'الأنعام',
        reciterName: 'محمد/أحمد',
      );

      expect(name.contains('/'), isFalse);
      expect(name, '006 - الأنعام - محمد أحمد.mp3');
    });

    test('بيشيل باقي الحروف الممنوعة في أسماء الملفات', () {
      final name = AudioExportService.exportFileName(
        surahId: 18,
        surahName: r'الكهف: *?"<>|\ ',
        reciterName: 'قارئ',
      );

      for (final banned in [':', '*', '?', '"', '<', '>', '|', r'\']) {
        expect(name.contains(banned), isFalse, reason: 'لسه فيه $banned');
      }
    });

    test('المسافات المتكررة بتتلمّ في مسافة واحدة', () {
      expect(
        AudioExportService.exportFileName(
          surahId: 3,
          surahName: 'آل    عمران',
          reciterName: 'قارئ   تاني',
        ),
        '003 - آل عمران - قارئ تاني.mp3',
      );
    });

    test('الاسم الفاضي بيبقى "غير معروف" مش فراغ', () {
      expect(
        AudioExportService.exportFileName(
          surahId: 1,
          surahName: '   ',
          reciterName: '',
        ),
        '001 - غير معروف - غير معروف.mp3',
      );
    });
  });
}
