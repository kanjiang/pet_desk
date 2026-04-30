import { HealthReading, MoodBaseline, MoodSnapshot } from './MoodReading';

const BASELINE_READY_SAMPLES: number = 7;
const DEFAULT_STRESSED_HEART_RATE: number = 100;
const DEFAULT_LOW_HRV: number = 28;
const DEFAULT_RELAXED_HRV: number = 55;

export function inferMood(reading: HealthReading, baseline: MoodBaseline): MoodSnapshot {
  if (isStressed(reading, baseline)) {
    return {
      level: 'stressed',
      reason: '心率明显偏高且压力较高',
      updatedAt: reading.collectedAt,
      latestReading: reading,
    };
  }

  if (isLow(reading, baseline)) {
    return {
      level: 'low',
      reason: '恢复指标偏低且近期睡眠较弱',
      updatedAt: reading.collectedAt,
      latestReading: reading,
    };
  }

  if (isRelaxed(reading, baseline)) {
    return {
      level: 'relaxed',
      reason: '恢复指标较好且压力较低',
      updatedAt: reading.collectedAt,
      latestReading: reading,
    };
  }

  return {
    level: 'normal',
    reason: baseline.sampleCount < BASELINE_READY_SAMPLES ? '基线样本不足，保持保守判断' : '当前状态平稳',
    updatedAt: reading.collectedAt,
    latestReading: reading,
  };
}

function isStressed(reading: HealthReading, baseline: MoodBaseline): boolean {
  if (reading.heartRate === undefined || reading.stress === undefined) {
    return false;
  }

  const heartRateThreshold: number = baseline.restingHeartRate !== undefined
    ? baseline.restingHeartRate * 1.25
    : DEFAULT_STRESSED_HEART_RATE;

  return reading.heartRate >= heartRateThreshold && reading.stress >= 70;
}

function isLow(reading: HealthReading, baseline: MoodBaseline): boolean {
  if (reading.hrv === undefined || reading.sleepScore === undefined) {
    return false;
  }

  const hrvThreshold: number = baseline.hrvMedian !== undefined
    ? baseline.hrvMedian * 0.7
    : DEFAULT_LOW_HRV;

  return reading.hrv <= hrvThreshold && reading.sleepScore < 60;
}

function isRelaxed(reading: HealthReading, baseline: MoodBaseline): boolean {
  if (reading.hrv === undefined || reading.stress === undefined) {
    return false;
  }

  const hrvThreshold: number = baseline.hrvMedian !== undefined
    ? baseline.hrvMedian * 1.1
    : DEFAULT_RELAXED_HRV;

  return reading.hrv >= hrvThreshold && reading.stress < 30;
}
/**
 * Mood Inferrer - 把手表健康数据快照映射成宠物心情信号.
 *
 * 设计要点 (详见 docs/DESIGN-MOOD.md):
 * - 必须基于个人 baseline 而不是绝对阈值
 * - 输出 confidence, 由上层决定是否触发安慰行为
 * - 不做任何医疗判断, 仅作陪伴体验触发信号
 */

export interface HealthSnapshot {
  hr: number;
  hrv: number;
  stress: number;
  isActive: boolean;
  sleepQualityLast24h: number;
}

export interface Baseline {
  hrResting: number;
  hrv: number;
  stress: number;
}

export type MoodLevel = 'relaxed' | 'normal' | 'stressed' | 'low';

export interface MoodReading {
  level: MoodLevel;
  confidence: number;
  reason: string;
  generatedAt: number;
}

export function inferMood(snap: HealthSnapshot, base: Baseline): MoodReading {
  const now: number = Date.now();

  if (!snap.isActive && snap.hr > base.hrResting * 1.25 && snap.stress > 70) {
    return {
      level: 'stressed',
      confidence: 0.8,
      reason: 'static_high_hr_and_stress',
      generatedAt: now,
    };
  }

  if (snap.hrv < base.hrv * 0.7 && snap.sleepQualityLast24h < 60) {
    return {
      level: 'low',
      confidence: 0.7,
      reason: 'low_hrv_and_poor_sleep',
      generatedAt: now,
    };
  }

  if (snap.hrv > base.hrv * 1.1 && snap.stress < 30) {
    return {
      level: 'relaxed',
      confidence: 0.6,
      reason: 'high_hrv_low_stress',
      generatedAt: now,
    };
  }

  return {
    level: 'normal',
    confidence: 0.5,
    reason: 'within_baseline',
    generatedAt: now,
  };
}
