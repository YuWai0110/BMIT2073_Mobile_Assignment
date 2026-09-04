import 'package:intl/intl.dart';

String formatRm(num amount) => NumberFormat.currency(
  locale: 'en_MY',
  symbol: 'RM ',
  decimalDigits: 2,
).format(amount);
