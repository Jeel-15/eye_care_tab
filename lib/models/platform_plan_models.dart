class PlatformPlanData {
  final int monthlyPrice;
  final int quarterlyDiscount;
  final int yearlyDiscount;
  final int trialDays;
  final int graceDays;
  final int quarterlyPrice;
  final int yearlyPrice;
  final int quarterlyOriginal;
  final int yearlyOriginal;
  final List<String> features;

  const PlatformPlanData({
    required this.monthlyPrice,
    required this.quarterlyDiscount,
    required this.yearlyDiscount,
    required this.trialDays,
    required this.graceDays,
    required this.quarterlyPrice,
    required this.yearlyPrice,
    required this.quarterlyOriginal,
    required this.yearlyOriginal,
    required this.features,
  });

  factory PlatformPlanData.fromJson(Map<String, dynamic> json) => PlatformPlanData(
        monthlyPrice:      (json['monthly_price']      as num).toInt(),
        quarterlyDiscount: (json['quarterly_discount'] as num).toInt(),
        yearlyDiscount:    (json['yearly_discount']    as num).toInt(),
        trialDays:         (json['trial_days']         as num).toInt(),
        graceDays:         (json['grace_days']         as num).toInt(),
        quarterlyPrice:    (json['quarterly_price']    as num).toInt(),
        yearlyPrice:       (json['yearly_price']       as num).toInt(),
        quarterlyOriginal: (json['quarterly_original'] as num).toInt(),
        yearlyOriginal:    (json['yearly_original']    as num).toInt(),
        features:          (json['features'] as List).cast<String>(),
      );
}
