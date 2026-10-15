/// All permission action keys — single source of truth.
/// Values mirror the backend's new flat permission-matrix keys
/// (`config/permission_matrix.php` on the web project). Identifiers below
/// are kept stable across the old→new key rewrite so call sites don't need
/// to change — only the string values moved from the old dotted scheme
/// (`opd.patient.view`) to the new flat one (`patient_view`).
abstract class Perm {
  // ── OPD — Patient ────────────────────────────────────────────────────────
  static const opdPatientRegister      = 'patient_register';
  static const opdPatientRegisterPhone = 'patient_register_phone';
  static const opdPatientView          = 'patient_view';
  static const opdPatientEdit          = 'patient_edit';
  static const opdPatientDelete        = 'patient_delete';

  // ── OPD — Exam ───────────────────────────────────────────────────────────
  static const opdExamPrimary          = 'exam_primary';
  static const opdExamSecondary        = 'exam_secondary';
  static const opdExamHistory          = 'exam_history';

  // ── OPD — Billing / Prescription ─────────────────────────────────────────
  static const opdBillPrint            = 'bill_print';
  static const opdPrescriptionPrint    = 'prescription_print';

  // ── OPD — FOC ────────────────────────────────────────────────────────────
  // No equivalent in the new permission matrix — the FOC feature's backend
  // routes/model are gone entirely from the current API (confirmed absent
  // from routes/api.php and app/), independent of this permission rewrite.
  // Left as the old dotted string (always resolves false for non-super
  // roles now) until FOC's backend status is resolved with the web dev.
  static const opdFocCreate            = 'opd.foc.create';
  static const opdFocAccept            = 'opd.foc.accept';

  // ── OPD — Reports ────────────────────────────────────────────────────────
  static const opdReportsView          = 'opd_reports_view';
  static const opdReportsExport        = 'opd_reports_export';

  // ── OT — Booking (legacy pre-Round-3 flow; still gates the "OT Bookings" nav item) ──
  static const otBookingCreate         = 'ot_booking_create';
  static const otBookingModify         = 'ot_booking_modify';
  static const otBookingCancel         = 'ot_booking_cancel';
  static const otCounsellingFill       = 'ot_counselling_fill';
  static const otPatientList           = 'ot_patient_list';
  static const otPackageSet            = 'ot_package_set';
  // OT — Appointment module (Round 3 Phase 2 — new booking/appointment flow)
  static const otAppointmentView       = 'ot_appointment_view';
  static const otAppointmentCreate     = 'ot_appointment_create';
  static const otAppointmentEdit       = 'ot_appointment_edit';
  // OT — Consent capture (Round 3 Phase 1)
  static const otConsentCapture        = 'ot_consent_capture';
  // OT — Doctor's "Recommend Surgery" handoff (Round 3.5)
  static const otSurgeryRecommend      = 'ot_surgery_recommend';

  // ── OT — Payment ─────────────────────────────────────────────────────────
  static const otPaymentRecord         = 'ot_payment_record';
  static const otPaymentExport         = 'ot_payment_export';

  // ── OT — Ward / Pre-Op ───────────────────────────────────────────────────
  static const otWardEntry             = 'ot_ward_entry';
  static const otPreopEntry            = 'ot_preop_entry';
  static const otDilationTrack         = 'ot_dilation_track';

  // ── OT — Surgery ─────────────────────────────────────────────────────────
  static const otSurgeryReady          = 'ot_surgery_ready';
  static const otSurgeryRecord         = 'ot_surgery_record';

  // ── OT — Lens ────────────────────────────────────────────────────────────
  static const otLensRecord            = 'ot_lens_record';
  static const otLensImplant           = 'ot_lens_implant';
  static const otMedsTakehome          = 'ot_meds_takehome';

  // ── OT — Invoice / Billing / Discharge ───────────────────────────────────
  static const otInvoiceView           = 'ot_invoice_view';
  static const otInvoiceEdit           = 'ot_invoice_edit';
  static const otBillingManage         = 'ot_billing_manage';
  static const otDischargeGenerate     = 'ot_discharge_generate';
  static const otDischargePatient      = 'ot_discharge_patient';
  static const otCertificatePrint      = 'ot_certificate_print';
  static const otBillPrint             = 'ot_bill_print';

  // ── OT — Appointment confirm / cancel ────────────────────────────────────
  static const otAppointmentConfirm    = 'ot_appointment_confirm';
  static const otAppointmentCancel     = 'ot_appointment_cancel';

  // ── Dashboard widgets ────────────────────────────────────────────────────
  static const dashboardClinical       = 'dashboard_clinical';
  static const dashboardReception      = 'dashboard_reception';
  static const dashboardRevenue        = 'dashboard_revenue';
  static const dashboardOt             = 'dashboard_ot';
  static const dashboardStaff          = 'dashboard_staff';

  // ── Masters ──────────────────────────────────────────────────────────────
  static const masterCaseTypes         = 'casetype_view';
  static const masterDoctors           = 'user_doctor_view';
  static const masterDoctorAdd         = 'user_doctor_add';
  static const masterDoctorEdit        = 'user_doctor_edit';
  static const masterDoctorDelete      = 'user_doctor_delete';
  static const masterReceptions        = 'user_reception_view';
  static const masterReceptionAdd      = 'user_reception_add';
  static const masterReceptionEdit     = 'user_reception_edit';
  static const masterReceptionDelete   = 'user_reception_delete';
  static const masterOtStaff           = 'user_ot_staff_view';
  static const masterOtStaffAdd        = 'user_ot_staff_add';
  static const masterOtStaffEdit       = 'user_ot_staff_edit';
  static const masterOtStaffDelete     = 'user_ot_staff_delete';
  static const masterRoles             = 'role_view';
  static const masterRoleAdd           = 'role_add';
  static const masterRoleEdit          = 'role_edit';
  static const masterRoleDelete        = 'role_delete';
  static const masterLocations         = 'location_view';
  static const masterMedicines         = 'medicine_view';
  static const masterMedicineAdd       = 'medicine_add';
  static const masterMedicineEdit      = 'medicine_edit';
  static const masterMedicineDelete    = 'medicine_delete';
  static const masterEyeExam           = 'eye_exam_master_view';
  static const masterEyeExamAdd        = 'eye_exam_master_add';
  static const masterEyeExamEdit       = 'eye_exam_master_edit';
  static const masterEyeExamDelete     = 'eye_exam_master_delete';
  // Granular Eye Exam master permissions. Each feature uses the standard
  // `${feature}_{view|add|edit|delete}` action suffixes.
  static const eyeExamFeatures = <String>[
    'eye_exam_chief_complaints',
    'eye_exam_kco',
    'eye_exam_hno',
    'eye_exam_diagnosis',
    'eye_exam_advice',
    'eye_exam_vn',
    'eye_exam_vngl',
    'eye_exam_vnst',
    'eye_exam_pnvn',
    'eye_exam_nrvn',
    'eye_exam_sph_cyl',
    'eye_exam_axis',
    'eye_exam_nct',
    'eye_exam_sac',
    'eye_exam_lid',
    'eye_exam_conj',
    'eye_exam_cornea',
    'eye_exam_ac',
    'eye_exam_iris',
    'eye_exam_pupil',
    'eye_exam_lens',
    'eye_exam_em',
    'eye_exam_covertest',
    'eye_exam_disc',
    'eye_exam_fr',
  ];
  static final Map<String, List<String>> eyeExamCrudKeys = {
    for (final feature in eyeExamFeatures)
      feature: [
        '${feature}_view',
        '${feature}_add',
        '${feature}_edit',
        '${feature}_delete',
      ],
  };
  static const masterOtSlots           = 'ot_slot_view';
  static const masterOtSlotAdd         = 'ot_slot_add';
  static const masterOtSlotEdit        = 'ot_slot_edit';
  static const masterOtSlotDelete      = 'ot_slot_delete';
  static const masterCaseTypeAdd       = 'casetype_add';
  static const masterCaseTypeEdit      = 'casetype_edit';
  static const masterCaseTypeDelete    = 'casetype_delete';
  static const masterReferrerView      = 'referrer_view';
  static const masterReferrerAdd       = 'referrer_add';
  static const masterReferrerEdit      = 'referrer_edit';
  static const masterReferrerDelete    = 'referrer_delete';
  static const masterDurationView      = 'duration_view';
  static const masterDurationAdd       = 'duration_add';
  static const masterDurationEdit      = 'duration_edit';
  static const masterDurationDelete    = 'duration_delete';
  static const masterLocationAdd       = 'location_add';
  static const masterLocationEdit      = 'location_edit';
  static const masterLocationDelete    = 'location_delete';
  static const masterOtTypes           = 'ot_type_view';
  static const masterOtTypeAdd         = 'ot_type_add';
  static const masterOtTypeEdit        = 'ot_type_edit';
  static const masterOtTypeDelete      = 'ot_type_delete';
  static const masterOtSurgeryTypeView   = 'ot_surgery_type_view';
  static const masterOtSurgeryTypeAdd    = 'ot_surgery_type_add';
  static const masterOtSurgeryTypeEdit   = 'ot_surgery_type_edit';
  static const masterOtSurgeryTypeDelete = 'ot_surgery_type_delete';
  static const masterOtCharges         = 'ot_charge_view';
  static const masterOtChargeAdd       = 'ot_charge_add';
  static const masterOtChargeEdit      = 'ot_charge_edit';
  static const masterOtChargeDelete    = 'ot_charge_delete';
  static const masterOtInventory       = 'ot_inventory_view';
  static const masterOtInventoryAdd    = 'ot_inventory_add';
  static const masterOtInventoryEdit   = 'ot_inventory_edit';
  static const masterOtInventoryDelete = 'ot_inventory_delete';
  static const masterOtLensOptionView  = 'ot_lens_option_view';
  static const masterOtLensOptionAdd   = 'ot_lens_option_add';
  static const masterOtLensOptionEdit  = 'ot_lens_option_edit';
  static const masterOtLensOptionDelete = 'ot_lens_option_delete';
  static const masterOtLensPowerView   = 'ot_lens_power_view';
  static const masterOtLensPowerAdd    = 'ot_lens_power_add';
  static const masterOtLensPowerEdit   = 'ot_lens_power_edit';
  static const masterOtLensPowerDelete = 'ot_lens_power_delete';
  static const masterOtPackageView     = 'ot_package_master_view';
  static const masterOtPackageAdd      = 'ot_package_master_add';
  static const masterOtPackageEdit     = 'ot_package_master_edit';
  static const masterOtPackageDelete   = 'ot_package_master_delete';

  // ── Settings ─────────────────────────────────────────────────────────────
  static const settingsHospital        = 'setting_hospital_view';
  static const settingsHospitalEdit    = 'setting_hospital_edit';
  static const settingsSubscription    = 'setting_subscription_view';

  // ── Reports ──────────────────────────────────────────────────────────────
  static const reportsView             = 'report_view';
  static const reportsExport           = 'report_export';
  static const otReportsView           = 'ot_reports_view';
  static const otReportsExport         = 'ot_reports_export';
}
