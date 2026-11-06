import 'dart:async';
import 'dart:convert';

import 'package:adhkari/models/quran_models.dart';
import 'package:adhkari/services/quran_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const stampKey = 'quran_cache_timestamp';
  const fixtures = <String, Map<String, Object>>{
    'reciters': {
      'id': 7,
      'name': 'عبد الباسط عبد الصمد',
      'moshaf': [
        {
          'id': 12,
          'name': 'حفص عن عاصم',
          'server': 'https://audio.example.test/reciter/',
          'surah_list': '1,2,114',
        },
      ],
    },
    'suwar': {'id': 1, 'name': 'الفاتحة', 'makkia': 1},
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    QuranApiService.clearMemoryCache();
  });

  tearDown(QuranApiService.clearMemoryCache);

  for (final endpoint in fixtures.keys) {
    final fixture = fixtures[endpoint]!;
    final cacheKey = 'quran_${endpoint}_cache';
    final Future<List<Object>> Function() fetch = endpoint == 'reciters'
        ? QuranApiService.fetchReciters
        : QuranApiService.fetchSuwar;

    List<Object> toCache(List<Object> values) => values
        .map(
          (value) =>
              value is Reciter ? value.toCache() : (value as Surah).toCache(),
        )
        .toList();

    void seedCache({required Duration age, String? raw}) {
      SharedPreferences.setMockInitialValues({
        cacheKey: raw ?? jsonEncode([fixture]),
        stampKey: DateTime.now().subtract(age).millisecondsSinceEpoch,
      });
    }

    group('QuranApiService $endpoint', () {
      test('uses fresh disk cache without making a network request', () async {
        seedCache(age: const Duration(days: 6));
        var requests = 0;
        final client = MockClient((_) async {
          requests++;
          throw http.ClientException('Network must not be used');
        });
        addTearDown(client.close);

        await http.runWithClient(() async {
          expect(toCache(await fetch()), [fixture]);
        }, () => client);

        expect(requests, 0);
      });

      test(
        'refreshes expired cache, preserves Arabic and persists results',
        () async {
          seedCache(
            age: const Duration(days: 8),
            raw: jsonEncode([
              {...fixture, 'id': 99, 'name': 'قديم'},
            ]),
          );
          final before = DateTime.now().millisecondsSinceEpoch;
          var requests = 0;
          final client = MockClient((request) async {
            requests++;
            expect(request.method, 'GET');
            expect(
              request.url,
              Uri.parse('https://mp3quran.net/api/v3/$endpoint?language=ar'),
            );
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  endpoint: [fixture, null, 'ignored'],
                }),
              ),
              200,
            );
          });
          addTearDown(client.close);

          await http.runWithClient(() async {
            final result = await fetch();
            expect(toCache(result), [fixture]);
            expect(await fetch(), same(result));

            final prefs = await SharedPreferences.getInstance();
            expect(jsonDecode(prefs.getString(cacheKey)!), [fixture]);
            expect(prefs.getInt(stampKey), greaterThanOrEqualTo(before));

            QuranApiService.clearMemoryCache();
            expect(toCache(await fetch()), [fixture]);
          }, () => client);

          expect(requests, 1);
        },
      );

      test('coalesces concurrent requests into one fetch', () async {
        final response = Completer<http.Response>();
        final requested = Completer<void>();
        var requests = 0;
        final client = MockClient((_) {
          requests++;
          requested.complete();
          return response.future;
        });
        addTearDown(client.close);

        await http.runWithClient(() async {
          final first = fetch();
          final second = fetch();
          await requested.future;
          response.complete(
            http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  endpoint: [fixture],
                }),
              ),
              200,
            ),
          );

          final results = await Future.wait([first, second]);
          expect(results[0], same(results[1]));
          expect(toCache(results[0]), [fixture]);
        }, () => client);

        expect(requests, 1);
      });

      for (final failure in [
        'offline',
        'http error',
        'malformed JSON',
        'empty',
      ]) {
        test(
          'falls back to stale cache on $failure without renewing it',
          () async {
            seedCache(age: const Duration(days: 8));
            final prefs = await SharedPreferences.getInstance();
            final previousStamp = prefs.getInt(stampKey);
            var requests = 0;
            final client = MockClient((_) async {
              requests++;
              return switch (failure) {
                'offline' => throw http.ClientException('Offline'),
                'http error' => http.Response('Unavailable', 503),
                'malformed JSON' => http.Response('{', 200),
                _ => http.Response(jsonEncode({endpoint: []}), 200),
              };
            });
            addTearDown(client.close);

            await http.runWithClient(() async {
              expect(toCache(await fetch()), [fixture]);
            }, () => client);

            expect(requests, 1);
            expect(prefs.getInt(stampKey), previousStamp);
            expect(jsonDecode(prefs.getString(cacheKey)!), [fixture]);
          },
        );
      }

      test(
        'ignores corrupt fresh cache and allows retry after network failure',
        () async {
          seedCache(age: const Duration(hours: 1), raw: '{broken');
          var requests = 0;
          final client = MockClient((_) async {
            requests++;
            if (requests == 1) return http.Response('Unavailable', 503);
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  endpoint: [fixture],
                }),
              ),
              200,
            );
          });
          addTearDown(client.close);

          await http.runWithClient(() async {
            await expectLater(
              fetch(),
              throwsA(
                isA<QuranApiException>().having(
                  (error) => error.message,
                  'message',
                  contains('503'),
                ),
              ),
            );
            expect(toCache(await fetch()), [fixture]);
          }, () => client);

          expect(requests, 2);
        },
      );
    });
  }
}
