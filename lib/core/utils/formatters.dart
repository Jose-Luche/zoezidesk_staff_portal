import 'package:intl/intl.dart';

final _kes = NumberFormat.decimalPattern('en_KE');
final _date = DateFormat('d MMM yyyy');

/// Amounts are whole shillings, as stored by the backend.
String formatKes(num amount) => 'KES ${_kes.format(amount)}';

String formatDate(DateTime date) => _date.format(date);

/// "just now", "5 min ago", "3 h ago", "yesterday", "12 Oct 2026".
String formatRelative(DateTime then, DateTime now) {
  final diff = now.difference(then);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'yesterday';
  return _date.format(then);
}

/// 07…, 01…, 7…, +254… → 2547XXXXXXXX, as the backend's PhoneNumber does.
String normalizeKenyanPhone(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) return '254${digits.substring(1)}';
  if (digits.startsWith('7') || digits.startsWith('1')) return '254$digits';
  return digits;
}

/// A Safaricom number that can receive an M-Pesa prompt.
bool isMpesaPhone(String input) =>
    RegExp(r'^254(7|1)\d{8}$').hasMatch(normalizeKenyanPhone(input));

/// 254712345678 → "0712 345 678".
String formatLocalPhone(String phone) {
  final n = normalizeKenyanPhone(phone);
  if (n.length != 12 || !n.startsWith('254')) return phone;
  final local = '0${n.substring(3)}';
  return '${local.substring(0, 4)} ${local.substring(4, 7)} ${local.substring(7)}';
}
