/// All permission action keys — single source of truth.
/// Mirrors PermissionsSeeder.php + migration 2026_04_11_200000_add_ot_billing_manage_permission.php
abstract class Perm {
  // ── OPD — Patient ────────────────────────────────────────────────────────
  static const opdPatientRegister      = 'opd.patient.register';
  static const opdPatientRegisterPhone = 'opd.patient.register_phone';
  static const opdPatientView          = 'opd.patient.view';
  static const opdPatientEdit          = 'opd.patient.edit';
  static const opdPatientDelete        = 'opd.patient.delete';

  // ── OPD — Exam ───────────────────────────────────────────────────────────
  static const opdExamPrimary          = 'opd.exam.primary';
  static const opdExamSecondary        = 'opd.exam.secondary';
  static const opdExamHistory          = 'opd.exam.history';

  // ── OPD — Billing / Prescription ─────────────────────────────────────────
  static const opdBillPrint            = 'opd.bill.print';
  static const opdPrescriptionPrint    = 'opd.prescription.print';

  // ── OPD — FOC ────────────────────────────────────────────────────────────
  static const opdFocCreate            = 'opd.foc.create';
  static const opdFocAccept            = 'opd.foc.accept';

  // ── OPD — Reports ────────────────────────────────────────────────────────
  static const opdReportsView          = 'opd.reports.view';
  static const opdReportsExport        = 'opd.reports.export';

  // ── OT — Booking (legacy pre-Round-3 flow; still gates the "OT Bookings" nav item) ──
  static const otBookingCreate         = 'ot.booking.create';
  static const otBookingModify         = 'ot.booking.modify';
  static const otBookingCancel         = 'ot.booking.cancel';
  static const otCounsellingFill       = 'ot.counselling.fill';
  static const otPatientList           = 'ot.patient.list';
  static const otPackageSet            = 'ot.package.set';
  // OT — Appointment module (Round 3 Phase 2 — new booking/appointment flow)
  static const otAppointmentView       = 'ot.appointment.view';
  static const otAppointmentCreate     = 'ot.appointment.create';
  static const otAppointmentEdit       = 'ot.appointment.edit';
  // OT — Consent capture (Round 3 Phase 1)
  static const otConsentCapture        = 'ot.consent.capture';
  // OT — Doctor's "Recommend Surgery" handoff (Round 3.5)
  static const otSurgeryRecommend      = 'ot.surgery.recommend';

  // ── OT — Payment ─────────────────────────────────────────────────────────
  static const otPaymentRecord         = 'ot.payment.record';
  static const otPaymentExport         = 'ot.payment.export';

  // ── OT — Ward / Pre-Op ───────────────────────────────────────────────────
  static const otWardEntry             = 'ot.ward.entry';
  static const otPreopEntry            = 'ot.preop.entry';
  static const otDilationTrack         = 'ot.dilation.track';

  // ── OT — Surgery ─────────────────────────────────────────────────────────
  static const otSurgeryReady          = 'ot.surgery.ready';
  static const otSurgeryRecord         = 'ot.surgery.record';

  // ── OT — Lens ────────────────────────────────────────────────────────────
  static const otLensRecord            = 'ot.lens.record';
  static const otLensImplant           = 'ot.lens.implant';
  static const otMedsTakehome          = 'ot.meds.takehome';

  // ── OT — Invoice / Billing / Discharge ───────────────────────────────────
  static const otInvoiceView           = 'ot.invoice.view';
  static const otInvoiceEdit           = 'ot.invoice.edit';
  static const otBillingManage         = 'ot.billing.manage';
  static const otDischargeGenerate     = 'ot.discharge.generate';
  static const otDischargePatient      = 'ot.discharge.patient';
  static const otCertificatePrint      = 'ot.certificate.print';
  static const otBillPrint             = 'ot.bill.print';

  // ── Masters ──────────────────────────────────────────────────────────────
  static const masterCaseTypes         = 'master.case_types';
  static const masterDoctors           = 'master.doctors';
  static const masterReceptions        = 'master.receptions';
  static const masterOtStaff           = 'master.ot_staff';
  static const masterRoles             = 'master.roles';
  static const masterLocations         = 'master.locations';
  static const masterMedicines         = 'master.medicines';
  static const masterEyeExam           = 'master.eye_exam';
  static const masterOtSlots           = 'master.ot_slots';
  static const masterOtTypes           = 'master.ot_types';
  static const masterOtCharges         = 'master.ot_charges';
  // Lens Inventory / Lens Powers / Packages masters (Round 3 Phase 7) — also
  // gates the corrected OT Lens Options route (Round 3.5)
  static const masterOtInventory       = 'master.ot_inventory';

  // ── Settings ─────────────────────────────────────────────────────────────
  static const settingsHospital        = 'settings.hospital';
  static const settingsSubscription    = 'settings.subscription';

  // ── Reports ──────────────────────────────────────────────────────────────
  static const reportsView             = 'reports.view';
  static const reportsExport           = 'reports.export';
}
