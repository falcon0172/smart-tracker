class SetAnalytics {
  final int totalReps;
  final double peakGyroDegS;
  final double peakAccelG;
  final double avgRepDurationSec;
  final double tempoConsistencyPercent;
  final double fatigueIndexPercent;

  const SetAnalytics({
    required this.totalReps,
    required this.peakGyroDegS,
    required this.peakAccelG,
    required this.avgRepDurationSec,
    required this.tempoConsistencyPercent,
    required this.fatigueIndexPercent,
  });

  factory SetAnalytics.empty() {
    return const SetAnalytics(
      totalReps: 0,
      peakGyroDegS: 0.0,
      peakAccelG: 0.0,
      avgRepDurationSec: 0.0,
      tempoConsistencyPercent: 100.0,
      fatigueIndexPercent: 0.0,
    );
  }
}
