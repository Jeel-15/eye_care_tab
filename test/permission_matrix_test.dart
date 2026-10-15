import 'package:eye_care_tab/models/auth_models.dart';
import 'package:eye_care_tab/models/permission_matrix.dart';
import 'package:eye_care_tab/services/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(PermissionService.instance.clear);

  test('matrix exposes granular eye exam CRUD keys', () {
    expect(PermissionMatrix.eyeExamMasterTypes, hasLength(25));
    for (final type in PermissionMatrix.eyeExamMasterTypes) {
      for (final action in const ['view', 'add', 'edit', 'delete']) {
        expect(PermissionMatrix.allKeys, contains('${type.$1}_$action'));
      }
    }
  });

  test('legacy eye exam verbs expand to matching granular verbs', () {
    final expanded = PermissionMatrix.expandGranted(
      const ['eye_exam_master_edit'],
    );
    expect(
      expanded.where((key) => key.startsWith('eye_exam_') && key.endsWith('_edit')),
      hasLength(26),
    );
    expect(expanded, contains('eye_exam_cornea_edit'));
    expect(expanded, isNot(contains('eye_exam_cornea_add')));
  });

  test('OT report and surgery type keys belong to correct features', () {
    expect(PermissionMatrix.moduleOf('ot_reports_view'), 'ot');
    expect(PermissionMatrix.keyToFeature['ot_reports_export'], 'ot_reports');
    expect(
      PermissionMatrix.keyToFeature['ot_surgery_type_delete'],
      'ot_surgery_type',
    );
  });

  test('permission service recognizes granular master access', () {
    PermissionService.instance.load(
      const RoleInfo(
        id: 1,
        name: 'Limited',
        slug: 'limited',
        color: '#000000',
        isSuper: false,
        permissions: ['eye_exam_lens_add'],
      ),
    );
    expect(PermissionService.instance.canAccessEyeExamMasters, isTrue);
    expect(PermissionService.instance.canAccessMasters, isTrue);
    expect(
      PermissionService.instance.canFeature('master', 'eye_exam_lens'),
      isTrue,
    );
  });
}
