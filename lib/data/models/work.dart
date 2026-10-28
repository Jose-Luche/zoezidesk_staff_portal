import 'members.dart';

/// One scheduled class on the day.
class ClassItem {
  const ClassItem({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.booked,
    required this.status,
    required this.mine,
    required this.canSeeRoster,
    this.instructor,
  });

  factory ClassItem.fromJson(Map<String, dynamic> json) => ClassItem(
        id: json['id'] as int,
        name: json['name'] as String? ?? 'Class',
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        capacity: json['capacity'] as int,
        booked: json['booked'] as int,
        status: json['status'] as String,
        mine: json['mine'] as bool? ?? false,
        canSeeRoster: json['can_see_roster'] as bool? ?? false,
        instructor: json['instructor'] as String?,
      );

  final int id;
  final String name;
  final String startTime;
  final String endTime;
  final int capacity;
  final int booked;
  final String status;

  /// Taught by the signed-in trainer.
  final bool mine;
  final bool canSeeRoster;
  final String? instructor;
}

/// A member's training at a glance (MuscleAnalyticsService on the server).
class TrainingSummary {
  const TrainingSummary({required this.goal, required this.sessions28d, required this.attention, this.lastWorkout, this.daysSinceWorkout});

  factory TrainingSummary.fromJson(Map<String, dynamic> json) => TrainingSummary(
        goal: json['goal']?.toString() ?? '',
        lastWorkout: json['last_workout'] == null ? null : DateTime.parse(json['last_workout'] as String),
        daysSinceWorkout: json['days_since_workout'] as int?,
        sessions28d: json['sessions_28d'] as int? ?? 0,
        attention: [
          for (final a in (json['attention'] as List? ?? const []).cast<Map<String, dynamic>>())
            (muscle: '${a['label'] ?? a['muscle'] ?? ''}', status: '${a['status'] ?? ''}'),
        ],
      );

  final String goal;
  final DateTime? lastWorkout;
  final int? daysSinceWorkout;
  final int sessions28d;
  final List<({String muscle, String status})> attention;
}

class TrainerNote {
  const TrainerNote({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.note,
    required this.sessionDate,
    this.trainer,
    this.member,
    this.mine = false,
  });

  factory TrainerNote.fromJson(Map<String, dynamic> json) => TrainerNote(
        id: json['id'] as int,
        type: json['type'] as String,
        typeLabel: json['type_label'] as String? ?? '',
        note: json['note'] as String,
        sessionDate: DateTime.parse(json['session_date'] as String),
        trainer: json['trainer'] as String?,
        member: json['member'] as String?,
        mine: json['mine'] as bool? ?? false,
      );

  final int id;

  /// session, progress, health or general.
  final String type;
  final String typeLabel;
  final String note;
  final DateTime sessionDate;
  final String? trainer;
  final String? member;
  final bool mine;
}

class TrainerClient {
  const TrainerClient({required this.card, this.training});

  final MemberCard card;
  final TrainingSummary? training;
}

class TrainerDashboard {
  const TrainerDashboard({
    required this.checkInsToday,
    required this.clients,
    required this.needsAttention,
    required this.expiringSoon,
    required this.recentNotes,
  });

  factory TrainerDashboard.fromJson(Map<String, dynamic> json) {
    TrainingSummary? training(Object? t) => t == null ? null : TrainingSummary.fromJson(t as Map<String, dynamic>);
    return TrainerDashboard(
      checkInsToday: json['check_ins_today'] as int? ?? 0,
      clients: [
        for (final m in (json['members'] as List).cast<Map<String, dynamic>>())
          TrainerClient(card: MemberCard.fromJson(m), training: training(m['training'])),
      ],
      needsAttention: [
        for (final row in (json['needs_attention'] as List).cast<Map<String, dynamic>>())
          (
            client: TrainerClient(
              card: MemberCard.fromJson(row['member'] as Map<String, dynamic>),
              training: training(row['training']),
            ),
            inactive: row['inactive'] as bool? ?? false,
          ),
      ],
      expiringSoon: [for (final m in (json['expiring_soon'] as List).cast<Map<String, dynamic>>()) MemberCard.fromJson(m)],
      recentNotes: [for (final n in (json['recent_notes'] as List).cast<Map<String, dynamic>>()) TrainerNote.fromJson(n)],
    );
  }

  final int checkInsToday;
  final List<TrainerClient> clients;
  final List<({TrainerClient client, bool inactive})> needsAttention;
  final List<MemberCard> expiringSoon;
  final List<TrainerNote> recentNotes;
}

/// Owner and manager figures. Kept close to the server's shape; the
/// screens read the few numbers they show.
class TodayReport {
  const TodayReport({required this.kpis, required this.revenueSeries, required this.attendanceSeries});

  factory TodayReport.fromJson(Map<String, dynamic> json) => TodayReport(
        kpis: json['kpis'] as Map<String, dynamic>,
        revenueSeries: [for (final v in ((json['revenue'] as Map)['values'] as List)) (v as num).toDouble()],
        attendanceSeries: [for (final v in ((json['attendance'] as Map)['values'] as List)) (v as num).toDouble()],
      );

  final Map<String, dynamic> kpis;
  final List<double> revenueSeries;
  final List<double> attendanceSeries;

  num kpi(String key) => kpis[key] as num? ?? 0;
}

class PeriodReport {
  const PeriodReport({required this.revenue, required this.attendance, required this.memberships});

  factory PeriodReport.fromJson(Map<String, dynamic> json) => PeriodReport(
        revenue: json['revenue'] as Map<String, dynamic>,
        attendance: json['attendance'] as Map<String, dynamic>,
        memberships: json['memberships'] as Map<String, dynamic>,
      );

  final Map<String, dynamic> revenue;
  final Map<String, dynamic> attendance;
  final Map<String, dynamic> memberships;
}
