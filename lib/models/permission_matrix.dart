/// Dart mirror of the backend's `config/permission_matrix.php` — the
/// module → feature → action-key tree. This is the one place that needs
/// updating when the server-side matrix changes; `PermissionService`'s
/// `canModule()`/`canFeature()` are built on the lookups derived here
/// instead of parsing key strings.
library;

class PermissionAction {
  final String key;
  final String label;
  const PermissionAction(this.key, this.label);
}

class PermissionFeature {
  final String key;
  final String label;
  final List<PermissionAction> actions;
  const PermissionFeature(this.key, this.label, this.actions);
}

class PermissionModule {
  final String key;
  final String label;
  final List<PermissionFeature> features;
  const PermissionModule(this.key, this.label, this.features);
}

List<PermissionAction> _crud(String feature) => [
      PermissionAction('${feature}_view', 'View'),
      PermissionAction('${feature}_add', 'Add'),
      PermissionAction('${feature}_edit', 'Edit'),
      PermissionAction('${feature}_delete', 'Delete'),
    ];

class PermissionMatrix {
  PermissionMatrix._();

  static const List<(String, String)> eyeExamMasterTypes = [
    ('eye_exam_chief_complaints', 'Chief Complaints'),
    ('eye_exam_kco', 'K/C/O'),
    ('eye_exam_hno', 'H/O'),
    ('eye_exam_diagnosis', 'Diagnoses'),
    ('eye_exam_advice', 'Advice'),
    ('eye_exam_vn', 'V/N'),
    ('eye_exam_vngl', 'Vn C GL'),
    ('eye_exam_vnst', 'Vn C ST'),
    ('eye_exam_pnvn', 'PH NV/N'),
    ('eye_exam_nrvn', 'NR V/N'),
    ('eye_exam_sph_cyl', 'SPH / CYL'),
    ('eye_exam_axis', 'Axis'),
    ('eye_exam_nct', 'NCT (IOP)'),
    ('eye_exam_sac', 'SAC'),
    ('eye_exam_lid', 'Lid'),
    ('eye_exam_conj', 'Conjunctiva'),
    ('eye_exam_cornea', 'Cornea'),
    ('eye_exam_ac', 'A/C'),
    ('eye_exam_iris', 'Iris'),
    ('eye_exam_pupil', 'Pupil'),
    ('eye_exam_lens', 'Lens'),
    ('eye_exam_em', 'E/M'),
    ('eye_exam_covertest', 'Cover Test'),
    ('eye_exam_disc', 'Disc'),
    ('eye_exam_fr', 'F/R'),
  ];

  static final List<PermissionModule> modules = [
    PermissionModule('dashboard', 'Dashboard', [
      PermissionFeature('widgets', 'Home widgets', const [
        PermissionAction('dashboard_clinical', 'Clinical / OPD stats & queues'),
        PermissionAction('dashboard_reception', 'Reception stats'),
        PermissionAction('dashboard_revenue', 'Revenue / collection'),
        PermissionAction('dashboard_ot', 'OT appointments'),
        PermissionAction('dashboard_staff', 'Staff overview'),
      ]),
    ]),
    PermissionModule('opd', 'OPD', [
      PermissionFeature('patient', 'Patients', const [
        PermissionAction('patient_view', 'View'),
        PermissionAction('patient_register', 'Add (walk-in)'),
        PermissionAction('patient_register_phone', 'Add (phone)'),
        PermissionAction('patient_edit', 'Edit'),
        PermissionAction('patient_delete', 'Delete'),
      ]),
      PermissionFeature('exam', 'Eye Exam', const [
        PermissionAction('exam_primary', 'Primary exam'),
        PermissionAction('exam_secondary', 'Secondary exam'),
        PermissionAction('exam_history', 'View history'),
        PermissionAction('prescription_print', 'Print prescription'),
      ]),
      PermissionFeature('billing', 'OPD Billing', const [
        PermissionAction('bill_print', 'Print bill'),
      ]),
      PermissionFeature('opd_reports', 'OPD Reports', const [
        PermissionAction('opd_reports_view', 'View'),
        PermissionAction('opd_reports_export', 'Export'),
      ]),
    ]),
    PermissionModule('ot', 'OT / Surgery', [
      PermissionFeature('ot_appointment', 'OT Appointments', const [
        PermissionAction('ot_appointment_view', 'View'),
        PermissionAction('ot_appointment_create', 'Add / book'),
        PermissionAction('ot_appointment_edit', 'Edit'),
        PermissionAction('ot_appointment_confirm', 'Confirm'),
        PermissionAction('ot_appointment_cancel', 'Cancel'),
      ]),
      PermissionFeature('ot_booking', 'OT Booking', const [
        PermissionAction('ot_booking_create', 'Add'),
        PermissionAction('ot_booking_modify', 'Edit'),
        PermissionAction('ot_booking_cancel', 'Cancel / delete'),
        PermissionAction('ot_patient_list', 'View patient list'),
      ]),
      PermissionFeature('ot_counselling', 'Counselling', const [
        PermissionAction('ot_counselling_fill', 'Fill form'),
        PermissionAction('ot_consent_capture', 'Capture consent'),
        PermissionAction('ot_package_set', 'Set package'),
      ]),
      PermissionFeature('ot_payment', 'OT Payments', const [
        PermissionAction('ot_payment_record', 'Add payment'),
        PermissionAction('ot_payment_export', 'Export'),
        PermissionAction('ot_invoice_view', 'View invoice'),
        PermissionAction('ot_invoice_edit', 'Edit invoice'),
        PermissionAction('ot_billing_manage', 'Manage billing docs'),
        PermissionAction('ot_bill_print', 'Print bill'),
      ]),
      PermissionFeature('ot_ward', 'Ward / Pre-Op', const [
        PermissionAction('ot_ward_entry', 'Ward admission'),
        PermissionAction('ot_preop_entry', 'Pre-op vitals'),
        PermissionAction('ot_dilation_track', 'Dilation tracking'),
      ]),
      PermissionFeature('ot_surgery', 'Surgery', const [
        PermissionAction('ot_surgery_recommend', 'Recommend'),
        PermissionAction('ot_surgery_ready', 'Ready to operate'),
        PermissionAction('ot_surgery_record', 'Record surgery'),
        PermissionAction('ot_lens_record', 'Record lens'),
        PermissionAction('ot_lens_implant', 'Mark implanted'),
        PermissionAction('ot_meds_takehome', 'Take-home meds'),
      ]),
      PermissionFeature('ot_discharge', 'Discharge', const [
        PermissionAction('ot_discharge_generate', 'Generate docs'),
        PermissionAction('ot_discharge_patient', 'Final discharge'),
        PermissionAction('ot_certificate_print', 'Print certificate'),
      ]),
      PermissionFeature('ot_reports', 'OT Reports', const [
        PermissionAction('ot_reports_view', 'View'),
        PermissionAction('ot_reports_export', 'Export'),
      ]),
    ]),
    PermissionModule('master', 'Masters / Config', [
      PermissionFeature('casetype', 'Case Types', _crud('casetype')),
      PermissionFeature('referrer', 'Referrers', _crud('referrer')),
      PermissionFeature('duration', 'Durations', _crud('duration')),
      PermissionFeature('location', 'Locations', _crud('location')),
      PermissionFeature('user_doctor', 'Doctors', _crud('user_doctor')),
      PermissionFeature('user_reception', 'Receptionists', _crud('user_reception')),
      PermissionFeature('user_ot_staff', 'OT Staff', _crud('user_ot_staff')),
      PermissionFeature('role', 'Roles & Permissions', _crud('role')),
      PermissionFeature('medicine', 'Medicines', _crud('medicine')),
      for (final type in eyeExamMasterTypes)
        PermissionFeature(type.$1, type.$2, _crud(type.$1)),
      PermissionFeature('ot_slot', 'OT Slots', _crud('ot_slot')),
      PermissionFeature('ot_type', 'OT Types', _crud('ot_type')),
      PermissionFeature('ot_surgery_type', 'OT Surgery Types', _crud('ot_surgery_type')),
      PermissionFeature('ot_charge', 'OT Charge Heads', _crud('ot_charge')),
      PermissionFeature('ot_lens_option', 'Lens Options', _crud('ot_lens_option')),
      PermissionFeature('ot_lens_power', 'Lens Powers', _crud('ot_lens_power')),
      PermissionFeature('ot_inventory', 'OT Lens Inventory', _crud('ot_inventory')),
      PermissionFeature('ot_package_master', 'OT Packages', _crud('ot_package_master')),
    ]),
    PermissionModule('setting', 'Settings', [
      PermissionFeature('hospital', 'Hospital', const [
        PermissionAction('setting_hospital_view', 'View'),
        PermissionAction('setting_hospital_edit', 'Edit'),
      ]),
      PermissionFeature('subscription', 'Subscription', const [
        PermissionAction('setting_subscription_view', 'View subscription'),
      ]),
    ]),
    PermissionModule('report', 'Reports', [
      PermissionFeature('reports', 'All Reports', const [
        PermissionAction('report_view', 'View'),
        PermissionAction('report_export', 'Export'),
      ]),
    ]),
  ];

  static final Map<String, String> keyToModule = {
    for (final m in modules)
      for (final f in m.features)
        for (final a in f.actions) a.key: m.key,
  };

  static final Map<String, String> keyToFeature = {
    for (final m in modules)
      for (final f in m.features)
        for (final a in f.actions) a.key: f.key,
  };

  static final Set<String> allKeys = keyToModule.keys.toSet();

  static String? moduleOf(String key) => keyToModule[key];

  /// Mirror of backend `config/permission_matrix.php` expand_map.
  /// Bundle/manage grants expand to concrete CRUD keys on login.
  /// Named `_crudKeys` so it does not shadow the top-level `_crud`
  /// (which returns `List<PermissionAction>` for the modules tree).
  static List<String> _crudKeys(String feature) => [
        '${feature}_view',
        '${feature}_add',
        '${feature}_edit',
        '${feature}_delete',
      ];

  static final Map<String, List<String>> expandMap = {
    'master.case_types': [..._crudKeys('casetype'), ..._crudKeys('referrer'), ..._crudKeys('duration')],
    'casetype_manage': [..._crudKeys('casetype'), ..._crudKeys('referrer'), ..._crudKeys('duration')],
    'master.locations': _crudKeys('location'),
    'location_manage': _crudKeys('location'),
    'master.medicines': _crudKeys('medicine'),
    'medicine_manage': _crudKeys('medicine'),
    'master.eye_exam': [
      for (final type in eyeExamMasterTypes) ..._crudKeys(type.$1),
    ],
    'eye_exam_master_manage': [
      for (final type in eyeExamMasterTypes) ..._crudKeys(type.$1),
    ],
    for (final verb in const ['view', 'add', 'edit', 'delete'])
      'eye_exam_master_$verb': [
        for (final type in eyeExamMasterTypes) '${type.$1}_$verb',
      ],
    'master.ot_slots': _crudKeys('ot_slot'),
    'ot_slot_manage': _crudKeys('ot_slot'),
    'master.ot_types': _crudKeys('ot_type'),
    'ot_type_manage': _crudKeys('ot_type'),
    'ot_surgery_type_manage': _crudKeys('ot_surgery_type'),
    'master.ot_charges': _crudKeys('ot_charge'),
    'ot_charge_manage': _crudKeys('ot_charge'),
    'master.ot_inventory': [
      ..._crudKeys('ot_inventory'),
      ..._crudKeys('ot_lens_option'),
      ..._crudKeys('ot_lens_power'),
      ..._crudKeys('ot_package_master'),
    ],
    'ot_inventory_manage': [
      ..._crudKeys('ot_inventory'),
      ..._crudKeys('ot_lens_option'),
      ..._crudKeys('ot_lens_power'),
      ..._crudKeys('ot_package_master'),
    ],
    'ot_lens_option_manage': _crudKeys('ot_lens_option'),
    'ot_lens_power_manage': _crudKeys('ot_lens_power'),
    'ot_package_master_manage': _crudKeys('ot_package_master'),
    'master.roles': _crudKeys('role'),
    'role_manage': _crudKeys('role'),
    'master.doctors': _crudKeys('user_doctor'),
    'user_doctor_manage': _crudKeys('user_doctor'),
    'master.receptions': _crudKeys('user_reception'),
    'user_reception_manage': _crudKeys('user_reception'),
    'master.ot_staff': _crudKeys('user_ot_staff'),
    'user_ot_staff_manage': _crudKeys('user_ot_staff'),
    'settings.hospital': const ['setting_hospital_view', 'setting_hospital_edit'],
    'setting_hospital': const ['setting_hospital_view', 'setting_hospital_edit'],
    'settings.subscription': const ['setting_subscription_view'],
    'setting_subscription': const ['setting_subscription_view'],
  };

  /// Expand manage/bundle keys present in [granted] into concrete action keys.
  static List<String> expandGranted(List<String> granted) {
    if (granted.isEmpty) return granted;
    final out = <String>{...granted};
    for (final key in granted) {
      final actions = expandMap[key];
      if (actions != null) out.addAll(actions);
    }
    return out.toList();
  }
}
