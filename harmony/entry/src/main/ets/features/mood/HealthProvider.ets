import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { HealthReading } from './MoodReading';

const TAG: string = 'PetDesk.HealthProvider';
const DOMAIN: number = 0xC001;

export interface HealthProvider {
  readLatest(context?: common.Context): Promise<HealthReading | null>;
}

export function normalizeHealthReading(input: {
  collectedAt: number;
  heartRate?: number;
  hrv?: number;
  stress?: number;
  sleepScore?: number;
}): HealthReading {
  return {
    collectedAt: input.collectedAt,
    heartRate: input.heartRate,
    hrv: input.hrv,
    stress: input.stress,
    sleepScore: input.sleepScore,
    source: 'health_kit',
  };
}

export class HarmonyHealthProvider implements HealthProvider {
  async readLatest(_context?: common.Context): Promise<HealthReading | null> {
    hilog.warn(DOMAIN, TAG, 'readLatest is awaiting local HealthServiceKit wiring in DevEco SDK');
    return null;
  }
}
