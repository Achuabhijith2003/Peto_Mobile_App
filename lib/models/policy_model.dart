class PolicyModel {
  final String id;
  final String slug;
  final String policyType;
  final String title;
  final String version;
  final String content;
  final String status;
  final DateTime? effectiveDate;
  final String? regionCode;
  final bool requiresAcknowledgement;
  final DateTime? publishedAt;

  PolicyModel({
    required this.id,
    required this.slug,
    required this.policyType,
    required this.title,
    required this.version,
    required this.content,
    required this.status,
    this.effectiveDate,
    this.regionCode,
    this.requiresAcknowledgement = false,
    this.publishedAt,
  });

  factory PolicyModel.fromJson(Map<String, dynamic> json) {
    return PolicyModel(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      policyType: json['policy_type']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Compliance Policy',
      version: json['version']?.toString() ?? '1.0.0',
      content: json['content']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PUBLISHED',
      effectiveDate: json['effective_date'] != null
          ? DateTime.tryParse(json['effective_date'].toString())
          : null,
      regionCode: json['region_code']?.toString() ?? 'GLOBAL',
      requiresAcknowledgement: json['requires_acknowledgement'] == true,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'].toString())
          : null,
    );
  }
}
