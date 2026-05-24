class MechaBuild {
  MechaBuild({
    this.generator = 20,
    this.hull = 25,
    this.shields = 15,
    this.cannon = 18,
    this.propulsion = 12,
    this.radar = 10,
  });

  int generator;
  int hull;
  int shields;
  int cannon;
  int propulsion;
  int radar;

  static const int minStat = 5;
  static const int maxStat = 70;
  static const int totalPoints = 100;

  int get sum =>
      generator + hull + shields + cannon + propulsion + radar;

  bool get isValid =>
      sum == totalPoints &&
      generator >= minStat &&
      hull >= minStat &&
      shields >= minStat &&
      cannon >= minStat &&
      propulsion >= minStat &&
      radar >= minStat &&
      generator <= maxStat &&
      hull <= maxStat &&
      shields <= maxStat &&
      cannon <= maxStat &&
      propulsion <= maxStat &&
      radar <= maxStat;

  Map<String, int> toJson() => {
        'generator': generator,
        'hull': hull,
        'shields': shields,
        'cannon': cannon,
        'propulsion': propulsion,
        'radar': radar,
      };

  MechaBuild copyWith({
    int? generator,
    int? hull,
    int? shields,
    int? cannon,
    int? propulsion,
    int? radar,
  }) {
    return MechaBuild(
      generator: generator ?? this.generator,
      hull: hull ?? this.hull,
      shields: shields ?? this.shields,
      cannon: cannon ?? this.cannon,
      propulsion: propulsion ?? this.propulsion,
      radar: radar ?? this.radar,
    );
  }
}
