enum MartialArtModality {
  brazilianJiuJitsu,
  judo,
  muayThai,
  karate,
  taekwondo,
  wrestling,
  mma,
}

extension MartialArtModalityLabel on MartialArtModality {
  String get label {
    switch (this) {
      case MartialArtModality.brazilianJiuJitsu:
        return 'Jiu-Jitsu Brasileiro';
      case MartialArtModality.judo:
        return 'Judô';
      case MartialArtModality.muayThai:
        return 'Muay Thai';
      case MartialArtModality.karate:
        return 'Karatê';
      case MartialArtModality.taekwondo:
        return 'Taekwondo';
      case MartialArtModality.wrestling:
        return 'Wrestling';
      case MartialArtModality.mma:
        return 'MMA';
    }
  }
}
