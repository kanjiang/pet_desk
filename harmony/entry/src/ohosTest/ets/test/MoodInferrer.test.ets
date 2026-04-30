import { describe, it, expect } from '@ohos/hypium';

import { normalizeHealthReading } from '../../../main/ets/features/mood/HealthProvider';
import { inferMood } from '../../../main/ets/features/mood/MoodInferrer';
import { HealthReading, MoodBaseline } from '../../../main/ets/features/mood/MoodReading';

describe('MoodInferrer', () => {
  it('falls back to normal when baseline is still cold-start and reading is mild', 0, () => {
    const reading: HealthReading = {
      collectedAt: 1,
      heartRate: 78,
      stress: 32,
      source: 'health_kit',
    };
    const baseline: MoodBaseline = {
      sampleCount: 0,
      updatedAt: 0,
    };

    const snapshot = inferMood(reading, baseline);
    expect(snapshot.level).assertEqual('normal');
  });

  it('infers stressed when heart rate is clearly above baseline and stress is high', 0, () => {
    const reading: HealthReading = {
      collectedAt: 1,
      heartRate: 108,
      stress: 82,
      source: 'health_kit',
    };
    const baseline: MoodBaseline = {
      restingHeartRate: 70,
      stressMedian: 30,
      sampleCount: 10,
      updatedAt: 1,
    };

    const snapshot = inferMood(reading, baseline);
    expect(snapshot.level).assertEqual('stressed');
  });

  it('infers low when hrv is below baseline and sleep score is poor', 0, () => {
    const reading: HealthReading = {
      collectedAt: 1,
      hrv: 24,
      sleepScore: 42,
      source: 'health_kit',
    };
    const baseline: MoodBaseline = {
      hrvMedian: 48,
      sampleCount: 12,
      updatedAt: 1,
    };

    const snapshot = inferMood(reading, baseline);
    expect(snapshot.level).assertEqual('low');
  });

  it('infers relaxed when hrv is above baseline and stress is low', 0, () => {
    const reading: HealthReading = {
      collectedAt: 1,
      hrv: 62,
      stress: 18,
      source: 'health_kit',
    };
    const baseline: MoodBaseline = {
      hrvMedian: 48,
      stressMedian: 35,
      sampleCount: 12,
      updatedAt: 1,
    };

    const snapshot = inferMood(reading, baseline);
    expect(snapshot.level).assertEqual('relaxed');
  });

  it('normalizes sparse health values into a HealthReading contract', 0, () => {
    const reading = normalizeHealthReading({
      collectedAt: 100,
      heartRate: 88,
      stress: undefined,
      hrv: 41,
      sleepScore: 72,
    });

    expect(reading.collectedAt).assertEqual(100);
    expect(reading.heartRate).assertEqual(88);
    expect(reading.hrv).assertEqual(41);
    expect(reading.source).assertEqual('health_kit');
  });
});
