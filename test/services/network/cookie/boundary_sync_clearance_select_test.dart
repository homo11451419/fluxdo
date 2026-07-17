import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxdo/services/network/cookie/boundary_sync_service.dart';

/// CF 双发 cf_clearance 选优:必须选「非分区主站」那枚,绝不选「分区
/// pre-clearance」那枚——后者同步进原生 jar 后 native 发送必被 CF 拒
/// (实测 partitioned=true 的 511 恒 403、非分区 575 才通过;会话内持续
/// 403、重启无解的根因)。
void main() {
  Cookie clearance(String value, {required int expiresDate}) => Cookie(
    name: 'cf_clearance',
    value: value,
    domain: '.linux.do',
    path: '/',
    isSecure: true,
    isHttpOnly: true,
    expiresDate: expiresDate,
  );

  final svc = BoundarySyncService.instance;

  group('BoundarySyncService cf_clearance 选优', () {
    test('分区属性可读:选非分区那枚,即便它过期更早', () {
      final nonPartitioned = clearance('x' * 575, expiresDate: 1000);
      final partitioned = clearance('y' * 511, expiresDate: 999999); // 过期更晚
      bool? partitionedOf(Cookie c) => c.value == partitioned.value;

      for (final cookies in [
        [nonPartitioned, partitioned],
        [partitioned, nonPartitioned],
      ]) {
        final selected = svc.selectBestWebViewCookieForTest(
          cookies,
          'linux.do',
          partitionedOf,
        );
        expect(selected?.value, nonPartitioned.value);
      }
    });

    test('分区属性不可读(macOS,均 null):退到值更长那枚', () {
      final longer = clearance('x' * 575, expiresDate: 1000); // 过期更早
      final shorter = clearance('y' * 511, expiresDate: 999999); // 过期更晚
      bool? partitionedOf(Cookie c) => null;

      for (final cookies in [
        [longer, shorter],
        [shorter, longer],
      ]) {
        final selected = svc.selectBestWebViewCookieForTest(
          cookies,
          'linux.do',
          partitionedOf,
        );
        expect(selected?.value, longer.value);
      }
    });

    test('无 partitionedOf 时也不按过期时间(退到值长度)', () {
      final longer = clearance('x' * 575, expiresDate: 1000);
      final shorter = clearance('y' * 511, expiresDate: 999999);
      final selected = svc.selectBestWebViewCookieForTest(
        [shorter, longer],
        'linux.do',
        null,
      );
      expect(selected?.value, longer.value);
    });
  });
}
