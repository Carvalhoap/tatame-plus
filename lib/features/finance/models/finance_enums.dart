enum BillingMode {
  monthlyFee,
  gympass,
  exempt,
}

enum BillingStatus {
  pending,
  underReview,
  paid,
  overdue,
  waived,
}

enum PaymentProofType {
  gympassCheckIn,
  monthlyFee,
}

enum PaymentProofStatus {
  pending,
  approved,
  rejected,
}

enum FinancialEntryType {
  income,
  expense,
}

enum PaymentMethod {
  pix,
  cash,
  card,
  bankTransfer,
  gympass,
  other,
}
