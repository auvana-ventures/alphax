import 'dart:convert';

import 'package:alphax/alphax.dart';
import 'package:alphax_test/alphax_test.dart';
import 'package:test/test.dart';

import 'package:waypoint/data/dio_waypoint_data_source.dart';
import 'package:waypoint/data/demo_waypoint_transport.dart';
import 'package:waypoint/data/waypoint_activity_stream.dart';
import 'package:waypoint/data/waypoint_data_source.dart';
import 'package:waypoint/data/waypoint_json.dart';

void main() {
  group('Waypoint demo data', () {
    test('loads a realistic trip workspace through AlphaX', () async {
      final source = DemoWaypointDataSource();
      addTearDown(source.close);

      final home = await source.loadHome();

      expect(home.trips, hasLength(2));
      expect(home.trips.first.destination, 'Kyoto, Japan');
      expect(home.places, isNotEmpty);
      expect(home.activities, hasLength(3));
    });

    test('cancels an in-flight search', () async {
      final source = DemoWaypointDataSource();
      addTearDown(source.close);
      final token = AlphaXCancellationToken();
      final search = source.searchPlaces('garden', cancellationToken: token);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      token.cancel('Search replaced');

      await expectLater(search, throwsA(isA<AlphaXCancellationException>()));
    });

    test('streams activity updates and transfers a document', () async {
      final source = DemoWaypointDataSource();
      addTearDown(source.close);

      final activities = await source.watchActivity().toList();
      final download = await source.downloadItinerary('kyoto');
      final upload = await source.uploadNote('kyoto');

      expect(activities, hasLength(3));
      expect(download.bytes, greaterThan(0));
      expect(upload.bytes, greaterThan(0));
      expect(download.protocol, AlphaXProtocol.http11);
    });

    test('can run the same REST surface through the Dio adapter', () async {
      final source = DioWaypointDataSource.demo();
      addTearDown(source.close);

      final home = await source.loadHome();
      final activities = await source.watchActivity().toList();

      expect(source.name, contains('Dio'));
      expect(home.trips.first.title, 'Kyoto, slowly');
      expect(activities, hasLength(3));
    });

    test(
      'Dio activity streaming can be cancelled before the first chunk',
      () async {
        final source = DioWaypointDataSource(
          client: AlphaXClient(
            transport: WaypointDemoTransport(
              latency: const Duration(milliseconds: 100),
            ),
          ),
          baseUri: Uri.parse('https://waypoint.demo/'),
          name: 'Dio + AlphaX cancellation fixture',
        );
        addTearDown(source.close);
        final token = AlphaXCancellationToken();
        final activities = source
            .watchActivity(cancellationToken: token)
            .toList();

        await Future<void>.delayed(const Duration(milliseconds: 10));
        token.cancel('Stop activity stream');

        await expectLater(
          activities,
          throwsA(isA<AlphaXCancellationException>()),
        );
      },
    );

    test('decodes activity JSON when UTF-8 crosses chunks', () {
      final decoder = WaypointActivityStreamDecoder();
      final bytes = utf8.encode('{"title":"café ☕"}\n');
      final split = bytes.indexOf(0xC3) + 1;

      decoder.add(bytes.sublist(0, split));
      expect(decoder.drain(), isEmpty);
      decoder.add(bytes.sublist(split));
      decoder.close();

      expect(decoder.drain(), <Object?>[
        <String, Object?>{'title': 'café ☕'},
      ]);
    });

    test('rejects unsuccessful file transfers', () async {
      final transport = FakeAlphaXTransport(
        response: AlphaXResponse(
          statusCode: 500,
          bodyBytes: utf8.encode('{"error":"fixture failure"}'),
          protocol: AlphaXProtocol.http11,
        ),
        streamBuilder: (_) async* {
          yield AlphaXResponseStarted(
            statusCode: 500,
            protocol: AlphaXProtocol.http11,
          );
          yield AlphaXResponseChunk(utf8.encode('{"error":"fixture failure"}'));
          yield const AlphaXResponseCompleted(
            bytesReceived: 27,
            metrics: AlphaXRequestMetrics(
              negotiatedProtocol: AlphaXProtocol.http11,
            ),
          );
        },
      );
      final source = AlphaXWaypointDataSource(
        client: AlphaXClient(transport: transport),
        baseUri: Uri.parse('https://waypoint.test/'),
      );
      addTearDown(source.close);

      await expectLater(
        source.downloadItinerary('kyoto'),
        throwsA(
          isA<WaypointDataException>().having(
            (error) => error.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
      await expectLater(
        source.uploadNote('kyoto'),
        throwsA(
          isA<WaypointDataException>().having(
            (error) => error.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });

    test('alphax_test provides deterministic file-transfer fixtures', () async {
      final transport = FakeAlphaXTransport(
        response: AlphaXResponse(
          statusCode: 200,
          bodyBytes: <int>[1, 2, 3, 4],
          protocol: AlphaXProtocol.http11,
        ),
      );
      final client = AlphaXClient(transport: transport);
      addTearDown(client.close);
      final target = InMemoryAlphaXFileTarget();

      final result = await client.download(
        Uri.parse('https://waypoint.test/itinerary'),
        to: target,
      );

      expect(result.bytesTransferred, 4);
      expect(target.bytes, <int>[1, 2, 3, 4]);
    });
  });
}
