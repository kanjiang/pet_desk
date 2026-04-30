import { common } from '@kit.AbilityKit';

import { PetEngine } from '../pet3d/PetEngine';
import { HealthProvider } from './HealthProvider';
import { inferMood } from './MoodInferrer';
import { MoodLevel, MoodSnapshot } from './MoodReading';
import { MoodStateRepo } from './MoodStateRepo';

const THROTTLE_MS: number = 30 * 60_000;

export class MoodEngineService {
  constructor(
    private readonly provider: HealthProvider,
    private readonly repo: Pick<MoodStateRepo, 'current' | 'currentBaseline' | 'save'>,
    private readonly dispatchMood: (level: 'low' | 'stressed' | 'relaxed') => void = defaultDispatchMood,
    private readonly now: () => number = () => Date.now(),
  ) {}

  async refresh(context?: common.Context): Promise<MoodSnapshot | undefined> {
    const reading = await this.provider.readLatest(context);
    if (!reading) {
      return this.repo.current();
    }

    const next: MoodSnapshot = inferMood(reading, this.repo.currentBaseline());
    const previous: MoodSnapshot | undefined = this.repo.current();
    const currentTime: number = this.now();
    const shouldTrigger: boolean = isTriggerLevel(next.level) && canTrigger(previous, next.level, currentTime);
    const persisted: MoodSnapshot = {
      ...next,
      lastTriggeredAt: shouldTrigger ? currentTime : previous?.lastTriggeredAt,
    };

    this.repo.save(persisted);

    if (shouldTrigger) {
      this.dispatchMood(next.level);
    }

    return persisted;
  }
}

function defaultDispatchMood(level: 'low' | 'stressed' | 'relaxed'): void {
  if (level === 'low' || level === 'stressed') {
    PetEngine.instance().dispatch({ type: 'mood_signal', level });
  }
}

function isTriggerLevel(level: MoodLevel): level is 'low' | 'stressed' | 'relaxed' {
  return level === 'low' || level === 'stressed' || level === 'relaxed';
}

function canTrigger(previous: MoodSnapshot | undefined, nextLevel: MoodLevel, now: number): boolean {
  if (!previous || previous.level !== nextLevel || previous.lastTriggeredAt === undefined) {
    return nextLevel === 'low' || nextLevel === 'stressed';
  }

  return now - previous.lastTriggeredAt >= THROTTLE_MS && (nextLevel === 'low' || nextLevel === 'stressed');
}
