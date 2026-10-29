/// The small front-desk card: enough to recognise a member and act on them,
/// nothing about their training.
class MemberCard {
  const MemberCard({
    required this.id,
    required this.name,
    required this.initials,
    required this.memberNumber,
    required this.phone,
    required this.status,
    this.photoUrl,
    this.membership,
  });

  factory MemberCard.fromJson(Map<String, dynamic> json) => MemberCard(
        id: json['id'] as int,
        name: json['name'] as String,
        initials: json['initials'] as String? ?? '',
        memberNumber: json['member_number'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
        photoUrl: json['photo_url'] as String?,
        membership: json['membership'] == null
            ? null
            : CardMembership.fromJson(json['membership'] as Map<String, dynamic>),
      );

  final int id;
  final String name;
  final String initials;
  final String memberNumber;
  final String phone;
  final String status;
  final String? photoUrl;
  final CardMembership? membership;

  /// Can be checked in: active, with a membership that hasn't ended.
  bool get isCurrent => status == 'active' && (membership?.current ?? false);
}

class CardMembership {
  const CardMembership({required this.plan, required this.expiresAt, required this.daysLeft, required this.current});

  factory CardMembership.fromJson(Map<String, dynamic> json) => CardMembership(
        plan: json['plan'] as String?,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        daysLeft: json['days_left'] as int,
        current: json['current'] as bool,
      );

  final String? plan;
  final DateTime expiresAt;
  final int daysLeft;
  final bool current;
}

/// `GET /members/{id}`: the card plus what this staff member may see.
class MemberProfile {
  const MemberProfile({
    required this.card,
    required this.details,
    required this.visitsThisMonth,
    required this.lastVisit,
    required this.payments,
    required this.canEdit,
    required this.canTakePayment,
    required this.canVoidPayments,
    required this.canViewTraining,
    required this.canManageNotes,
  });

  factory MemberProfile.fromJson(Map<String, dynamic> json) {
    final member = json['member'] as Map<String, dynamic>;
    final can = json['can'] as Map<String, dynamic>;
    final attendance = json['attendance'] as Map<String, dynamic>;
    final payments = json['payments'] as List?;
    return MemberProfile(
      card: MemberCard.fromJson(member),
      details: member,
      visitsThisMonth: attendance['this_month'] as int? ?? 0,
      lastVisit: attendance['last_visit'] == null ? null : DateTime.parse(attendance['last_visit'] as String),
      payments: payments == null ? null : [for (final p in payments) PaymentRecord.fromJson(p as Map<String, dynamic>)],
      canEdit: can['edit'] as bool? ?? false,
      canTakePayment: can['take_payment'] as bool? ?? false,
      canVoidPayments: can['void_payments'] as bool? ?? false,
      canViewTraining: can['view_training'] as bool? ?? false,
      canManageNotes: can['manage_notes'] as bool? ?? false,
    );
  }

  final MemberCard card;

  /// email, gender, date_of_birth, emergency contact, group, joined_at, notes.
  final Map<String, dynamic> details;
  final int visitsThisMonth;
  final DateTime? lastVisit;

  /// Null when this staff member may not see payments.
  final List<PaymentRecord>? payments;
  final bool canEdit;
  final bool canTakePayment;
  final bool canVoidPayments;
  final bool canViewTraining;
  final bool canManageNotes;
}

/// A member a new registration may be repeating.
class PossibleDuplicate {
  const PossibleDuplicate({required this.id, required this.name, required this.memberNumber, required this.matched});

  factory PossibleDuplicate.fromJson(Map<String, dynamic> json) => PossibleDuplicate(
        id: json['id'] as int,
        name: json['name'] as String,
        memberNumber: json['member_number'] as String? ?? '',
        matched: json['matched'] as String? ?? '',
      );

  final int id;
  final String name;
  final String memberNumber;
  final String matched;
}

class CheckInResult {
  const CheckInResult({required this.success, required this.duplicate, required this.message, this.member});

  factory CheckInResult.fromJson(Map<String, dynamic> json) => CheckInResult(
        success: json['success'] as bool? ?? false,
        duplicate: json['duplicate'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        member: json['member'] == null ? null : MemberCard.fromJson(json['member'] as Map<String, dynamic>),
      );

  final bool success;
  final bool duplicate;
  final String message;
  final MemberCard? member;
}

class TodayCheckIn {
  const TodayCheckIn({required this.at, required this.method, required this.member, this.by});

  factory TodayCheckIn.fromJson(Map<String, dynamic> json) => TodayCheckIn(
        at: DateTime.parse(json['checked_in_at'] as String).toLocal(),
        method: json['method'] as String? ?? 'qr',
        by: json['checked_in_by'] as String?,
        member: MemberCard.fromJson(json['member'] as Map<String, dynamic>),
      );

  final DateTime at;
  final String method;
  final String? by;
  final MemberCard member;
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.amount,
    required this.method,
    required this.status,
    this.member,
    this.memberPhone,
    this.plan,
    this.reference,
    this.paidAt,
    this.recordedBy,
    this.voidReason,
    this.hasReceipt = false,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: json['id'] as int,
        amount: json['amount'] as int,
        method: json['method'] as String,
        status: json['status'] as String,
        member: json['member'] as String?,
        memberPhone: json['member_phone'] as String?,
        plan: json['plan'] as String?,
        reference: json['reference'] as String?,
        paidAt: json['paid_at'] == null ? null : DateTime.parse(json['paid_at'] as String).toLocal(),
        recordedBy: json['recorded_by'] as String?,
        voidReason: json['void_reason'] as String?,
        hasReceipt: json['has_receipt'] as bool? ?? false,
      );

  final int id;
  final int amount;
  final String method;

  /// pending, completed, failed, cancelled or voided.
  final String status;
  final String? member;
  final String? memberPhone;
  final String? plan;
  final String? reference;
  final DateTime? paidAt;
  final String? recordedBy;
  final String? voidReason;
  final bool hasReceipt;

  String get methodLabel => switch (method) { 'mpesa' => 'M-Pesa', 'cash' => 'Cash', 'bank' => 'Bank', _ => method };
}

class Plan {
  const Plan({required this.id, required this.name, required this.price, required this.durationLabel, required this.category});

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        id: json['id'] as int,
        name: json['name'] as String,
        price: json['price'] as int,
        durationLabel: json['duration_label'] as String? ?? '',
        category: json['category'] as String? ?? 'standard',
      );

  final int id;
  final String name;
  final int price;
  final String durationLabel;
  final String category;
}

class Plans {
  const Plans({required this.mpesaEnabled, required this.plans});

  final bool mpesaEnabled;
  final List<Plan> plans;
}

/// A day's takings for one staff member, and everyone's for managers.
class Shift {
  const Shift({
    required this.date,
    required this.total,
    required this.count,
    required this.byMethod,
    required this.voidedCount,
    required this.voidedAmount,
    required this.payments,
    this.everyone,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    final s = json['summary'] as Map<String, dynamic>;
    final everyone = json['everyone'] as List?;
    return Shift(
      date: DateTime.parse(json['date'] as String),
      total: s['total'] as int,
      count: s['count'] as int,
      byMethod: {
        for (final MapEntry(:key, :value) in (s['by_method'] as Map<String, dynamic>).entries)
          key: (value as Map)['amount'] as int,
      },
      voidedCount: s['voided_count'] as int,
      voidedAmount: s['voided_amount'] as int,
      payments: [for (final p in json['payments'] as List) PaymentRecord.fromJson(p as Map<String, dynamic>)],
      everyone: everyone == null
          ? null
          : [
              for (final row in everyone.cast<Map<String, dynamic>>())
                (
                  staffId: (row['staff'] as Map)['id'] as int,
                  name: (row['staff'] as Map)['name'] as String,
                  total: row['total'] as int,
                  count: row['count'] as int,
                ),
            ],
    );
  }

  final DateTime date;
  final int total;
  final int count;

  /// cash / mpesa / bank → amount.
  final Map<String, int> byMethod;
  final int voidedCount;
  final int voidedAmount;
  final List<PaymentRecord> payments;
  final List<({int staffId, String name, int total, int count})>? everyone;
}

/// Someone to follow up: their membership ends soon, or ended without a renewal.
class FollowUp {
  const FollowUp({required this.member, required this.expiresAt, required this.days, this.plan});

  factory FollowUp.fromJson(Map<String, dynamic> json) => FollowUp(
        member: MemberCard.fromJson(json['member'] as Map<String, dynamic>),
        plan: json['plan'] as String?,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        days: json['days'] as int,
      );

  final MemberCard member;
  final String? plan;
  final DateTime expiresAt;

  /// Days until the end (negative once it has ended).
  final int days;
}

/// A walk-in enquiry (a lead in the web CRM).
class Enquiry {
  const Enquiry({
    required this.id,
    required this.name,
    required this.phone,
    required this.stage,
    required this.stageLabel,
    required this.createdAt,
    required this.overdue,
    this.interestedIn,
    this.notes,
    this.nextFollowUpAt,
  });

  factory Enquiry.fromJson(Map<String, dynamic> json) => Enquiry(
        id: json['id'] as int,
        name: json['name'] as String,
        phone: json['phone'] as String,
        stage: json['stage'] as String,
        stageLabel: json['stage_label'] as String? ?? '',
        interestedIn: json['interested_in_plan'] as String?,
        notes: json['notes'] as String?,
        nextFollowUpAt: json['next_follow_up_at'] == null ? null : DateTime.parse(json['next_follow_up_at'] as String).toLocal(),
        overdue: json['overdue'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );

  final int id;
  final String name;
  final String phone;

  /// new, contacted, interested or trial while open.
  final String stage;
  final String stageLabel;
  final String? interestedIn;
  final String? notes;
  final DateTime? nextFollowUpAt;
  final bool overdue;
  final DateTime createdAt;
}
