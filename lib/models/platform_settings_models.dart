class PlatformSettingsData {
  final String? platformName;
  final String? supportEmail;
  final String? trialDays;
  // Razorpay — masked if set
  final String? razorpayKey;
  final String? razorpaySecret;
  final String? razorpayWebhookSecret;
  final bool hasRazorpayKey;
  final bool hasRazorpaySecret;
  final bool hasRazorpayWebhookSecret;
  // Mail
  final String? mailHost;
  final String? mailPort;
  final String? mailUsername;
  final String? mailPassword; // masked if set
  final bool hasMailPassword;
  final String? mailFromName;
  final String? mailFromEmail;

  const PlatformSettingsData({
    this.platformName,
    this.supportEmail,
    this.trialDays,
    this.razorpayKey,
    this.razorpaySecret,
    this.razorpayWebhookSecret,
    this.hasRazorpayKey            = false,
    this.hasRazorpaySecret         = false,
    this.hasRazorpayWebhookSecret  = false,
    this.mailHost,
    this.mailPort,
    this.mailUsername,
    this.mailPassword,
    this.hasMailPassword           = false,
    this.mailFromName,
    this.mailFromEmail,
  });

  factory PlatformSettingsData.fromJson(Map<String, dynamic> json) => PlatformSettingsData(
        platformName:             json['platform_name']              as String?,
        supportEmail:             json['support_email']              as String?,
        trialDays:                json['trial_days']?.toString(),
        razorpayKey:              json['razorpay_key']               as String?,
        razorpaySecret:           json['razorpay_secret']            as String?,
        razorpayWebhookSecret:    json['razorpay_webhook_secret']    as String?,
        hasRazorpayKey:           json['has_razorpay_key']           as bool? ?? false,
        hasRazorpaySecret:        json['has_razorpay_secret']        as bool? ?? false,
        hasRazorpayWebhookSecret: json['has_razorpay_webhook_secret'] as bool? ?? false,
        mailHost:                 json['mail_host']                  as String?,
        mailPort:                 json['mail_port']?.toString(),
        mailUsername:             json['mail_username']              as String?,
        mailPassword:             json['mail_password']              as String?,
        hasMailPassword:          json['has_mail_password']          as bool? ?? false,
        mailFromName:             json['mail_from_name']             as String?,
        mailFromEmail:            json['mail_from_email']            as String?,
      );
}
