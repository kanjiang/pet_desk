import { describe, it, expect } from '@ohos/hypium';

import { MoodEngineService } from '../../../main/ets/features/mood/MoodEngineService';
import { HealthReading, MoodBaseline, MoodSnapshot } from '../../../main/ets/features/mood/MoodReading';

class FakeProvider {
  constructor(private readonly reading: HealthReading | null) {}

  async readLatest(): Promise<HealthReading | null> {
    return this.reading;
  }
}

class FakeRepo {
  public snapshot: MoodSnapshot | undefined = undefined;
  public baseline: MoodBaseline = { sampleCount: 0, updatedAt: 0 };

  current(): MoodSnapshot | undefined {
    return this.snapshot;
  }

  currentBaseline(): MoodBaseline {
    return this.baseline;
  }

  save(snapshot: MoodSnapshot): void {
    this.snapshot = snapshot;
  }
}

describe('MoodEngineService', () => {
  it('stores the inferred snapshot after a refresh', 0, async () => {
    const provider = new FakeProvider({
      collectedAt: 1,
      heartRate: 104,
      stress: 80,
      source: 'health_kit',
    });
    const repo = new FakeRepo();
    const service = new MoodEngineService(provider, repo as never);

    await service.refresh();
    expect(repo.snapshot?.level).assertEqual('stressed');
  });

  it('dispatches comfort for stressed on the first refresh', 0, async () => {
    const provider = new FakeProvider({
      collectedAt: 1,
      heartRate: 105,
      stress: 80,
      source: 'health_kit',
    });
    const repo = new FakeRepo();
    const calls: string[] = [];
    const service = new MoodEngineService(
      provider as never,
      repo as never,
      (level: 'low' | 'stressed' | 'relaxed'): void => {
        calls.push(level);
      },
    );

    await service.refresh();
    expect(calls.length).assertEqual(1);
    expect(calls[0]).assertEqual('stressed');
  });

  it('throttles repeated stressed triggers inside 30 minutes', 0, async () => {
    const provider = new FakeProvider({
      collectedAt: 10 * 60_000,
      heartRate: 105,
      stress: 80,
      source: 'health_kit',
    });
    const repo = new FakeRepo();
    repo.snapshot = {
      level: 'stressed',
      reason: 'old',
      updatedAt: 1,
      lastTriggeredAt: 1,
    };
    const calls: string[] = [];
    const service = new MoodEngineService(
      provider as never,
      repo as never,
      (level: 'low' | 'stressed' | 'relaxed'): void => {
        calls.push(level);
      },
      () => 10 * 60_000,
    );

    await service.refresh();
    expect(calls.length).assertEqual(0);
  });
});
