import 'dart:async';

import 'package:eye_care_tab/models/auth_models.dart';
import 'package:eye_care_tab/models/user_permission_policy.dart';
import 'package:eye_care_tab/services/auth_service.dart';
import 'package:eye_care_tab/services/permission_refresh_coordinator.dart';
import 'package:eye_care_tab/services/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(PermissionService.instance.clear);

  test('user categories map to exact permission families', () {
    expect(
      UserPermissionPolicy.permissionKey(UserCategory.doctor, 'edit'),
      'user_doctor_edit',
    );
    expect(
      UserPermissionPolicy.categoryFor(
        roleSlug: 'receptionist',
        roleName: 'Receptionist',
      ),
      UserCategory.reception,
    );
    expect(
      UserPermissionPolicy.categoryFor(
        roleSlug: 'front-desk',
        roleName: 'Reception Team',
      ),
      UserCategory.reception,
    );
    expect(
      UserPermissionPolicy.categoryFor(
        roleSlug: 'optometrist',
        roleName: 'Optometrist',
      ),
      UserCategory.otStaff,
    );
    expect(
      UserPermissionPolicy.categoryFor(
        roleSlug: 'ot_assistant',
        roleName: 'OT Assistant',
      ),
      UserCategory.otStaff,
    );
  });

  test('API-provided user category wins over the slug/name fallback', () {
    expect(
      UserPermissionPolicy.categoryFor(
        userCategory: 'reception',
        roleSlug: 'doctor-desk',
        roleName: 'Doctor Desk',
      ),
      UserCategory.reception,
    );
  });

  test('offline grace is bounded to 24 hours', () {
    final validated = DateTime.utc(2026, 9, 15, 12);
    expect(
      AuthService.isWithinOfflineGrace(
        validatedAt: validated,
        now: validated.add(const Duration(hours: 24)),
      ),
      isTrue,
    );
    expect(
      AuthService.isWithinOfflineGrace(
        validatedAt: validated,
        now: validated.add(const Duration(hours: 24, milliseconds: 1)),
      ),
      isFalse,
    );
    expect(
      AuthService.isWithinOfflineGrace(
        validatedAt: validated,
        now: validated.subtract(const Duration(seconds: 1)),
      ),
      isFalse,
    );
  });

  group('live permission refresh', () {
    const limitedRole = RoleInfo(
      id: 2,
      name: 'Limited',
      slug: 'limited',
      color: '#000000',
      isSuper: false,
      permissions: ['ot_reports_view'],
    );

    late DateTime now;
    late int calls;
    late Completer<void> gate;
    late PermissionRefreshCoordinator coordinator;

    setUp(() {
      now = DateTime.utc(2026, 9, 25, 10);
      calls = 0;
      gate = Completer<void>();
      coordinator = PermissionRefreshCoordinator(
        clock: () => now,
        refresh: () {
          calls++;
          return gate.future;
        },
      );
    });

    test('parallel triggers share one in-flight refresh', () async {
      final a = coordinator.trigger();
      final b = coordinator.trigger();
      final c = coordinator.trigger(fromResume: true);
      expect(identical(a, b), isTrue);
      expect(identical(a, c), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(coordinator.isRefreshing, isTrue);

      gate.complete();
      await a;
      expect(coordinator.isRefreshing, isFalse);
    });

    test('triggers within the debounce window are ignored', () async {
      gate.complete();
      await coordinator.trigger();
      now = now.add(const Duration(seconds: 2));
      await coordinator.trigger();
      expect(calls, 1);

      now = now.add(const Duration(seconds: 2));
      await coordinator.trigger();
      expect(calls, 2);
    });

    test('app-resume triggers are throttled to one per minute', () async {
      gate.complete();
      await coordinator.trigger(fromResume: true);
      now = now.add(const Duration(seconds: 30));
      await coordinator.trigger(fromResume: true);
      expect(calls, 1);

      // A server-driven trigger (header / 403) is only debounced.
      await coordinator.trigger();
      expect(calls, 2);

      now = now.add(const Duration(seconds: 61));
      await coordinator.trigger(fromResume: true);
      expect(calls, 3);
    });

    test('a failing refresh is swallowed and frees the slot', () async {
      final failing = PermissionRefreshCoordinator(
        clock: () => now,
        refresh: () async {
          calls++;
          throw Exception('offline');
        },
      );
      await failing.trigger();
      expect(failing.isRefreshing, isFalse);
      now = now.add(const Duration(seconds: 4));
      await failing.trigger();
      expect(calls, 2);
    });

    test('reset clears the debounce so a new session refreshes at once', () async {
      gate.complete();
      await coordinator.trigger();
      coordinator.reset();
      await coordinator.trigger();
      expect(calls, 2);
    });

    test('only a different, non-empty server version is stale', () {
      final p = PermissionService.instance;
      expect(p.isStale('abc123'), isFalse, reason: 'nothing loaded yet');

      p.load(limitedRole, version: 'abc123');
      expect(p.isStale(null), isFalse);
      expect(p.isStale(''), isFalse);
      expect(p.isStale('abc123'), isFalse);
      expect(p.isStale('def456'), isTrue);
    });

    test('hasModule prefers server modules and falls back to granted keys', () {
      final p = PermissionService.instance;
      p.load(limitedRole);
      expect(p.hasModule('ot'), isTrue);
      expect(p.hasModule('opd'), isFalse);

      p.load(limitedRole, modules: ['opd']);
      expect(p.hasModule('opd'), isTrue);
      expect(p.hasModule('ot'), isFalse);

      p.load(
        const RoleInfo(id: 1, name: 'Admin', slug: 'hospital_admin', color: '#000000', isSuper: true),
        modules: const [],
      );
      expect(p.hasModule('ot'), isTrue);
    });

    test('load notifies listeners only when permissions actually change', () {
      final p = PermissionService.instance;
      var notified = 0;
      void listener() => notified++;
      p.addListener(listener);
      addTearDown(() => p.removeListener(listener));

      p.load(limitedRole, version: 'v1');
      expect(notified, 1);
      p.load(limitedRole, version: 'v1');
      expect(notified, 1);
      p.load(limitedRole, modules: ['ot'], version: 'v2');
      expect(notified, 2);
      p.clear();
      expect(notified, 3);
      p.clear();
      expect(notified, 3);
    });

    test('module list parser accepts API objects and plain keys', () {
      expect(
        AuthService.parseModuleKeys([
          {'key': 'opd', 'label': 'OPD'},
          {'key': 'ot', 'label': 'OT'},
        ]),
        ['opd', 'ot'],
      );
      expect(AuthService.parseModuleKeys(['master']), ['master']);
      expect(AuthService.parseModuleKeys(null), isNull);
      expect(AuthService.parseModuleKeys('opd'), isNull);
    });
  });
}
