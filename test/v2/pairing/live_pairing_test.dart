import 'dart:convert';
import 'dart:io';

import 'package:codewalk/features/hosts/hosts_controller.dart';
import 'package:codewalk/features/pairing/pairing_controller.dart';
import 'package:codewalk/platform/endpoints/pairing_factory_io.dart';
import 'package:codewalk/platform/endpoints/probe_factory_io.dart';
import 'package:codewalk/platform/pairing/qr_image_decoder_io.dart';
import 'package:codewalk/platform/profiles/endpoint_profile_store.dart';
import 'package:codewalk/platform/storage/endpoint_credentials.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:zxing_lib/qrcode.dart';
import 'package:zxing_lib/zxing.dart';

import '../hosts/profile_store_test.dart' show Metadata, Secrets;
import 'fakes.dart' show FakeQrInput;

/// Explicit opt-in: the launcher owns the isolated server and keeps secrets in
/// memory/environment. Default root checks do not contact any user's service.
void main() {
  final address = Platform.environment['CODEWALK_PAIR_QA_ENDPOINT'];
  test(
    'authorized native pairing/password/QR/renewal/expiry/revocation preserve identity',
    () async {
      final endpoint = Uri.parse(address!);
      final password = Platform.environment['CODEWALK_PAIR_QA_PASSWORD']!;
      final newPassword =
          Platform.environment['CODEWALK_PAIR_QA_PASSWORD_NEXT']!;
      final backend = Metadata()
        ..values['cw2.profiles.importer-owned'] = 'preserve-me';
      final secrets = Secrets();
      final metadata = V2MetadataStore(backend: backend);
      final repository = EndpointProfileStore(
        metadata: metadata,
        credentials: EndpointCredentialVault(
          backend: secrets,
          beforeMutation: metadata.ensureSchema,
        ),
      );
      final prober = createEndpointProber();
      final hosts = HostsController(
        repository: repository,
        prober: prober,
        createId: () => 'native_profile',
      );
      final pairing = createEndpointPairing();
      final controller = PairingController(
        pairing: pairing,
        hosts: hosts,
        qr: FakeQrInput(),
      );
      addTearDown(() {
        controller.dispose();
        hosts.dispose();
      });

      Future<String> codeWith(String secret) async {
        final transport = IoEndpointHttpTransport(
          endpoint: endpoint,
          headers: basicEndpointHeaders(
            endpoint: endpoint,
            username: 'opencode',
            secret: () => secret,
          ),
        );
        try {
          final response = await transport.send(
            TransportRequest(
              method: 'POST',
              path: '/api/pair',
              headers: const {'Accept': 'application/json'},
            ),
          );
          try {
            expect(response.statusCode == 200, isTrue);
            final data = jsonDecode(
              utf8.decode(await response.readBytes(maxBytes: 65536)),
            );
            expect(data is Map && data['code'] is String, isTrue);
            return data['code'] as String;
          } finally {
            response.cancel();
          }
        } finally {
          transport.close();
        }
      }

      Future<String> qrLink(String code) async {
        final link = endpoint.resolve('auth/connect/$code').toString();
        final matrix = QRCodeWriter().encode(
          link,
          BarcodeFormat.qrCode,
          256,
          256,
        );
        final raster = image.Image(width: matrix.width, height: matrix.height);
        for (var y = 0; y < matrix.height; y++) {
          for (var x = 0; x < matrix.width; x++) {
            final color = matrix.get(x, y) ? 0 : 255;
            raster.setPixelRgb(x, y, color, color, color);
          }
        }
        final decoded = await QrImageDecodeTask(image.encodePng(raster)).result;
        expect(
          decoded == link,
          isTrue,
        ); // Never print live single-use material.
        return decoded!;
      }

      final assessment = await hosts.probe(endpoint, password);
      expect(assessment?.version == '2.0.22', isTrue);
      expect(
        await hosts.add(endpoint, 'Native QA', password, assessment!),
        isTrue,
      );
      final profile = (await repository.load()).single;
      final code = await codeWith(password);
      controller.input(await qrLink(code), profile: profile);
      expect(controller.receipt == null, isTrue);
      await controller.confirm();
      expect(controller.receipt?.canSave == true, isTrue);
      final first = controller.receipt!.credential!;
      expect(await controller.save('ignored-label'), isTrue);
      expect((await repository.load()).single.id == profile.id, isTrue);
      expect(
        (await repository.readCredential(profile))!.matches(first),
        isTrue,
      );
      expect(
        (await pairing
                    .redeem(
                      PairingCandidate(endpoint: endpoint, challenge: code),
                    )
                    .result)
                .status ==
            PairingStatus.rejected,
        isTrue,
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      await controller.renew(profile);
      expect(controller.receipt?.canSave == true, isTrue);
      final successor = controller.receipt!.credential!;
      expect(successor.expiresAt?.isAfter(first.expiresAt!) == true, isTrue);
      expect(
        (await prober.start(endpoint, first.secret).result).canUse,
        isTrue,
      );
      expect(await controller.save('ignored-label'), isTrue);
      expect((await repository.load()).single.label == 'Native QA', isTrue);

      // A purpose-authored, correctly signed short QA token tests the native
      // expiry guard without changing the host clock or claiming a 30-day wait.
      final expiry =
          '${DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + 2}';
      final key = Hmac(
        sha256,
        utf8.encode(password),
      ).convert(utf8.encode('opencode-session-v1')).bytes;
      final signed =
          '$expiry.${base64Url.encode(Hmac(sha256, key).convert(utf8.encode(expiry)).bytes).replaceAll('=', '')}';
      expect((await prober.start(endpoint, signed).result).canUse, isTrue);
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(
        (await prober.start(endpoint, signed).result).status ==
            EndpointStatus.authenticationRequired,
        isTrue,
      );

      stdout.writeln('CODEWALK_PAIRING_QA_ROTATE');
      var rotated = false;
      for (var i = 0; i < 100; i++) {
        if ((await prober.start(endpoint, newPassword).result).canUse) {
          rotated = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(rotated, isTrue);
      await hosts.check(profile);
      expect(
        hosts.assessments[profile.id]?.status ==
            EndpointStatus.authenticationRequired,
        isTrue,
      );
      expect(
        (await repository.readCredential(profile))!.matches(successor),
        isTrue,
      );
      controller.input(
        await qrLink(await codeWith(newPassword)),
        profile: profile,
      );
      await controller.confirm();
      expect(controller.receipt?.canSave == true, isTrue);
      expect(await controller.save('ignored-label'), isTrue);
      final reopened = EndpointProfileStore(
        metadata: metadata,
        credentials: EndpointCredentialVault(
          backend: secrets,
          beforeMutation: metadata.ensureSchema,
        ),
      );
      expect((await reopened.load()).single.id == profile.id, isTrue);
      expect(
        (await reopened.load()).single.endpoint == profile.endpoint,
        isTrue,
      );
      expect(
        backend.values['cw2.profiles.importer-owned'] == 'preserve-me',
        isTrue,
      );
      expect(
        (await prober
                .start(
                  endpoint,
                  (await reopened.readCredential(profile))!.secret,
                )
                .result)
            .canUse,
        isTrue,
      );
      stdout.writeln('CODEWALK_PAIRING_QA_PASSED');
    },
    skip: address == null
        ? 'Requires explicitly authorized isolated native 2.0.22 runtime'
        : false,
    timeout: const Timeout(Duration(seconds: 180)),
  );
}
