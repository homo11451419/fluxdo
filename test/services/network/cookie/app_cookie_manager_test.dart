import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxdo/services/network/cookie/app_cookie_manager.dart';
import 'package:fluxdo/services/network/cookie/cookie_jar_service.dart';

void main() {
  group('AppCookieManager.loadCookies', () {
    test('忽略 RequestOptions 上残留的旧 Cookie 头，始终使用 CookieJar 最新值', () async {
      final jar = CookieJar();
      final uri = Uri.parse('https://linux.do/session/csrf');
      await jar.saveFromResponse(uri, [Cookie('_t', 'new-token')..path = '/']);

      final manager = AppCookieManager(jar);
      final options = RequestOptions(
        path: '/session/csrf',
        baseUrl: 'https://linux.do',
        method: 'GET',
        headers: {HttpHeaders.cookieHeader: '_t=old-token; other=legacy'},
      );

      final cookieHeader = await manager.loadCookies(options);

      expect(cookieHeader, '_t=new-token');
      expect(cookieHeader, isNot(contains('old-token')));
      expect(cookieHeader, isNot(contains('other=legacy')));
    });

    test('同名同 path 冲突时优先使用 host-only 会话 Cookie', () async {
      final jar = CookieJar();
      final uri = Uri.parse('https://linux.do/session/csrf');
      await jar.saveFromResponse(uri, [
        Cookie('_t', 'host-token')..path = '/',
        Cookie('_t', 'domain-token')
          ..domain = '.linux.do'
          ..path = '/',
      ]);

      final manager = AppCookieManager(jar);
      final options = RequestOptions(
        path: '/session/csrf',
        baseUrl: 'https://linux.do',
        method: 'GET',
      );

      final cookieHeader = await manager.loadCookies(options);

      expect(cookieHeader, '_t=host-token');
      expect(cookieHeader, isNot(contains('domain-token')));
    });

    test('会话 Cookie 即使 path 不同也只发送主站根路径 winner', () async {
      final jar = CookieJar();
      final uri = Uri.parse('https://linux.do/session/csrf');
      await jar.saveFromResponse(uri, [
        Cookie('_t', 'root-token')..path = '/',
        Cookie('_t', 'scoped-token')..path = '/session',
      ]);

      final manager = AppCookieManager(jar);
      final options = RequestOptions(
        path: '/session/csrf',
        baseUrl: 'https://linux.do',
        method: 'GET',
      );

      final cookieHeader = await manager.loadCookies(options);

      expect(cookieHeader, '_t=root-token');
      expect(cookieHeader, isNot(contains('scoped-token')));
    });

    test('会话 Cookie 的 domain 污染副本不会发送到子域名', () async {
      final jar = CookieJar();
      await jar.saveFromResponse(Uri.parse('https://linux.do'), [
        Cookie('_t', 'polluted-token')
          ..domain = '.linux.do'
          ..path = '/',
      ]);

      final manager = AppCookieManager(jar);
      final options = RequestOptions(
        path: '/api/v1/oauth/user-info',
        baseUrl: 'https://cdk.linux.do',
        method: 'GET',
      );

      final cookieHeader = await manager.loadCookies(options);

      expect(cookieHeader, isEmpty);
    });

    test('非会话同名不同 path Cookie 仍按 RFC 同时发送', () async {
      final jar = CookieJar();
      final uri = Uri.parse('https://linux.do/session/csrf');
      await jar.saveFromResponse(uri, [
        Cookie('theme', 'root')..path = '/',
        Cookie('theme', 'scoped')..path = '/session',
      ]);

      final manager = AppCookieManager(jar);
      final options = RequestOptions(
        path: '/session/csrf',
        baseUrl: 'https://linux.do',
        method: 'GET',
      );

      final cookieHeader = await manager.loadCookies(options);

      expect(cookieHeader, contains('theme=scoped'));
      expect(cookieHeader, contains('theme=root'));
    });

    test('cf_clearance 双变体选更长(非分区)那枚,不按过期时间', () {
      // 还原 CF 双发形态:非分区主站 clearance 值更长(575 类)但过期更早;
      // 分区 pre-clearance 值更短(511 类)但过期更晚。读侧看不到 Partitioned,
      // 必须按值长度选中「更长=非分区」那枚,而不是过期更晚的分区那枚
      // (后者 native 发送必被 CF 拒 → 会话内持续 403、重启无解)。
      final now = DateTime.now();
      final nonPartitioned = Cookie('cf_clearance', 'x' * 575)
        ..domain = '.linux.do'
        ..path = '/'
        ..secure = true
        ..httpOnly = true
        ..expires = now.add(const Duration(hours: 10)); // 过期更早
      final partitioned = Cookie('cf_clearance', 'y' * 511)
        ..domain = '.linux.do'
        ..path = '/'
        ..secure = true
        ..httpOnly = true
        ..expires = now.add(const Duration(days: 30)); // 过期更晚

      for (final cookies in [
        [nonPartitioned, partitioned],
        [partitioned, nonPartitioned],
      ]) {
        final selected = AppCookieManager.selectCookiesForTest(
          cookies,
          Uri.parse('https://linux.do/topics/timings'),
        );
        final clearance = selected.where((c) => c.name == 'cf_clearance');
        expect(clearance, hasLength(1));
        expect(clearance.first.value.length, 575);
      }
    });
  });

  group('CookieJarService.buildCookieHeaderForRequest', () {
    test('CDK retry header 保留业务 domain cookie 且不带主站登录 cookie', () {
      final header = CookieJarService.buildCookieHeaderForRequest([
        Cookie('cf_clearance', 'cf-token')
          ..domain = '.linux.do'
          ..path = '/',
        Cookie('linux_do_cdk_session_id', 'cdk-token')
          ..domain = '.linux.do'
          ..path = '/',
        Cookie('_t', 'polluted-token')
          ..domain = '.linux.do'
          ..path = '/',
      ], Uri.parse('https://cdk.linux.do/api/v1/oauth/user-info'));

      expect(header, contains('cf_clearance=cf-token'));
      expect(header, contains('linux_do_cdk_session_id=cdk-token'));
      expect(header, isNot(contains('_t=')));
    });

    test('cf_clearance 双变体选更长(非分区)那枚,不按过期时间', () {
      final now = DateTime.now();
      final nonPartitioned = Cookie('cf_clearance', 'x' * 575)
        ..domain = '.linux.do'
        ..path = '/'
        ..expires = now.add(const Duration(hours: 10));
      final partitioned = Cookie('cf_clearance', 'y' * 511)
        ..domain = '.linux.do'
        ..path = '/'
        ..expires = now.add(const Duration(days: 30));

      for (final cookies in [
        [nonPartitioned, partitioned],
        [partitioned, nonPartitioned],
      ]) {
        final header = CookieJarService.buildCookieHeaderForRequest(
          cookies,
          Uri.parse('https://linux.do/topics/timings'),
        );
        expect(header, contains('x' * 575));
        expect(header, isNot(contains('y' * 511)));
      }
    });
  });
}
