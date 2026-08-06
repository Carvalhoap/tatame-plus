enum StripeColor { white, red, black }

class StripeProgress {
  final StripeColor color;

  final int earned;
  final int total;

  const StripeProgress({
    required this.color,
    required this.earned,
    required this.total,
  });
}
