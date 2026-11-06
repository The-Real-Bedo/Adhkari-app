import 'dart:async';
import 'dart:io';

import 'package:adhkari/models/quran_models.dart';
import 'package:adhkari/services/quran_download_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const documentsChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory documentsDirectory;

  final moshaf = Moshaf(
    id: 12,
    name: 'Hafs',
    server: 'https://audio.example.test/reciter/',
    surahList: {1, 2},
  );

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp(
      'quran_download_service_test_',
    );
    messenger.setMockMethodCallHandler(documentsChannel, (call) async {
      expect(call.method, 'getApplicationDocumentsDirectory');
      return documentsDirectory.path;
    });
    addTearDown(() async {
      for (final job in QuranDownloadService.activeJobs) {
        await job.cancel();
      }
      messenger.setMockMethodCallHandler(documentsChannel, null);
      if (await documentsDirectory.exists()) {
        await documentsDirectory.delete(recursive: true);
      }
    });
  });

  test(
    'promotes a complete stream atomically and reuses duplicate jobs',
    () async {
      final chunks = StreamController<List<int>>();
      final requestStarted = Completer<void>();
      var requests = 0;
      final client = MockClient.streaming((request, _) async {
        requests++;
        expect(request.method, 'GET');
        expect(request.url, Uri.parse(moshaf.audioUrlFor(1)!));
        requestStarted.complete();
        return http.StreamedResponse(chunks.stream, 200, contentLength: 5);
      });

      await http.runWithClient(() async {
        final first = QuranDownloadService.startDownload(7, moshaf, 1);
        final duplicate = QuranDownloadService.startDownload(7, moshaf, 1);
        expect(identical(duplicate, first), isTrue);
        expect(QuranDownloadService.activeJob(7, 12, 1), same(first));
        final progressFuture = first.stream.toList().timeout(
          const Duration(seconds: 3),
        );

        await requestStarted.future.timeout(const Duration(seconds: 3));
        chunks.add([1, 2]);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final target = File(
          '${documentsDirectory.path}/quran_audio/r7_m12_s001.mp3',
        );
        final partial = File('${target.path}.part');
        expect(await partial.exists(), isTrue);
        expect(await target.exists(), isFalse);

        chunks.add([3, 4, 5]);
        await chunks.close();
        final progress = await progressFuture;

        expect(progress.map((event) => (event.received, event.total)), [
          (2, 5),
          (5, 5),
          (5, 5),
        ]);
        expect(await target.readAsBytes(), [1, 2, 3, 4, 5]);
        expect(await partial.exists(), isFalse);
        expect(await QuranDownloadService.localPath(7, 12, 1), target.path);
        expect(QuranDownloadService.activeJob(7, 12, 1), isNull);
        expect(requests, 1);
      }, () => client);
    },
  );

  test(
    'network failure preserves a completed file and leaves no partial',
    () async {
      var requests = 0;
      final client = MockClient.streaming((_, _) async {
        requests++;
        throw http.ClientException('offline');
      });

      await http.runWithClient(() async {
        final target = File(
          '${documentsDirectory.path}/quran_audio/r7_m12_s001.mp3',
        )..createSync(recursive: true);
        target.writeAsBytesSync([8, 9, 10]);

        final job = QuranDownloadService.startDownload(7, moshaf, 1);
        await expectLater(
          job.stream.toList().timeout(const Duration(seconds: 3)),
          throwsA(isA<QuranDownloadException>()),
        );

        expect(requests, 1);
        expect(await target.readAsBytes(), [8, 9, 10]);
        expect(await File('${target.path}.part').exists(), isFalse);
        expect(await QuranDownloadService.localPath(7, 12, 1), target.path);
      }, () => client);
    },
  );

  test(
    'stream failure removes partial data without replacing the file',
    () async {
      final body = StreamController<List<int>>();
      final requestStarted = Completer<void>();
      final client = MockClient.streaming((_, _) async {
        requestStarted.complete();
        return http.StreamedResponse(body.stream, 200, contentLength: 8);
      });

      await http.runWithClient(() async {
        final target = File(
          '${documentsDirectory.path}/quran_audio/r7_m12_s001.mp3',
        )..createSync(recursive: true);
        target.writeAsBytesSync([8, 9, 10]);

        final job = QuranDownloadService.startDownload(7, moshaf, 1);
        final events = job.stream.toList().timeout(const Duration(seconds: 3));
        await requestStarted.future.timeout(const Duration(seconds: 3));
        body.add([1, 2, 3]);
        body.addError(http.ClientException('connection interrupted'));
        await body.close();

        await expectLater(events, throwsA(isA<QuranDownloadException>()));
        expect(await target.readAsBytes(), [8, 9, 10]);
        expect(await File('${target.path}.part').exists(), isFalse);
        expect(await QuranDownloadService.localPath(7, 12, 1), target.path);
      }, () => client);
    },
  );

  test('unavailable surah fails without making a network request', () async {
    var requests = 0;
    final client = MockClient.streaming((_, _) async {
      requests++;
      return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
    });
    final unavailable = Moshaf(
      id: 12,
      name: 'Hafs',
      server: moshaf.server,
      surahList: {1},
    );

    await http.runWithClient(() async {
      final job = QuranDownloadService.startDownload(7, unavailable, 2);
      await expectLater(
        job.stream.toList().timeout(const Duration(seconds: 3)),
        throwsA(isA<QuranDownloadException>()),
      );
      expect(QuranDownloadService.activeJob(7, 12, 2), isNull);
      expect(await QuranDownloadService.localPath(7, 12, 2), isNull);
    }, () => client);

    expect(requests, 0);
  });

  test(
    'reciter and moshaf identities stay separate when deleting one file',
    () async {
      final otherMoshaf = Moshaf(
        id: 13,
        name: 'Warsh',
        server: 'https://audio.example.test/other/',
        surahList: {1},
      );
      final client = MockClient.streaming((request, _) async {
        final bytes = request.url.path.codeUnits;
        return http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: bytes.length,
        );
      });

      await http.runWithClient(() async {
        final jobs = [
          QuranDownloadService.startDownload(7, moshaf, 1),
          QuranDownloadService.startDownload(8, moshaf, 1),
          QuranDownloadService.startDownload(7, otherMoshaf, 1),
        ];
        await Future.wait(
          jobs.map(
            (job) => job.stream.toList().timeout(const Duration(seconds: 3)),
          ),
        );

        final paths = await Future.wait([
          QuranDownloadService.localPath(7, 12, 1),
          QuranDownloadService.localPath(8, 12, 1),
          QuranDownloadService.localPath(7, 13, 1),
        ]);
        expect(paths.toSet().length, 3);
        expect(paths, everyElement(isNotNull));

        await QuranDownloadService.delete(8, 12, 1);
        expect(await QuranDownloadService.localPath(7, 12, 1), paths[0]);
        expect(await QuranDownloadService.localPath(8, 12, 1), isNull);
        expect(await QuranDownloadService.localPath(7, 13, 1), paths[2]);
      }, () => client);
    },
  );

  test('download listing ignores partial and unrelated files', () async {
    final audioDirectory = Directory('${documentsDirectory.path}/quran_audio')
      ..createSync(recursive: true);
    File('${audioDirectory.path}/r4_m5_s009.mp3').writeAsBytesSync([1, 2]);
    File('${audioDirectory.path}/r4_m5_s010.mp3.part').writeAsBytesSync([3]);
    File('${audioDirectory.path}/notes.mp3').writeAsBytesSync([4]);

    final downloads = await QuranDownloadService.listDownloads();

    expect(downloads, hasLength(1));
    expect(downloads.single.reciterId, 4);
    expect(downloads.single.moshafId, 5);
    expect(downloads.single.surahId, 9);
    expect(downloads.single.bytes, 2);
  });
}
