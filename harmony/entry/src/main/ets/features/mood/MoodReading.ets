export type MoodLevel = 'relaxed' | 'normal' | 'stressed' | 'low';

export interface HealthReading {
  collectedAt: number;
  heartRate?: number;
  hrv?: number;
  stress?: number;
  sleepScore?: number;
  source: 'health_kit';
}

export interface MoodBaseline {
  restingHeartRate?: number;
  hrvMedian?: number;
  stressMedian?: number;
  sampleCount: number;
  updatedAt: number;
}

export interface MoodSnapshot {
  level: MoodLevel;
  reason: string;
  updatedAt: number;
  lastTriggeredAt?: number;
  mutedUntil?: number;
  latestReading?: HealthReading;
}
