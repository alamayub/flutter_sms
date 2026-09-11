enum CalendarMode {
  bs('BS', 'वि.सं.'),
  ad('AD', 'ई.सं.');

  final String labelEn;
  final String labelNe;

  const CalendarMode(this.labelEn, this.labelNe);

  bool get isBs => this == CalendarMode.bs;
  bool get isAd => this == CalendarMode.ad;

  String localizedLabel(String languageCode) {
    return languageCode == 'ne' ? labelNe : labelEn;
  }
}
