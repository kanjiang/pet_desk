import { describe, it, expect } from '@ohos/hypium';

import { PetAction, PetMood, PetSnapshot } from '../../../main/ets/common/models/PetState';
import { defaultSkinProfile } from '../../../main/ets/common/models/SkinProfile';
import { DailySchedule, defaultSchedule, ScheduleRule } from '../../../main/ets/features/scheduler/ScheduleRule';
import { buildSurfaceSnapshot } from '../../../main/ets/common/services/PetSurfaceService';

function createPetSnapshot(action: PetAction = PetAction.PLAY_BALL, mood: PetMood = PetMood.PLAYFUL): PetSnapshot {
  return {
    petId: 'default',
    action,
    mood,
    energy: 72,
    hunger: 28,
    affection: 55,
    lastInteractionAt: 1,
    lastActionSource: 'user' as const,
    updatedAt: 2,
  };
}

function createSchedule(rules: ScheduleRule[]): DailySchedule {
  return {
    rules,
    createdAt: 0,
    updatedAt: 0,
  };
}

function buildSnapshotForTest(schedule: DailySchedule, now: string) {
  return buildSurfaceSnapshot({
    pet: createPetSnapshot(),
    skin: defaultSkinProfile('default', '小橘'),
    schedule,
    now: new Date(now),
  });
}

describe('PetSurfaceService', () => {
  it('builds a lightweight snapshot from core state', 0, () => {
    const snapshot = buildSnapshotForTest(defaultSchedule(), '2026-05-06T08:30:00');

    expect(snapshot.petName).assertEqual('小橘');
    expect(snapshot.currentAction).assertEqual(PetAction.PLAY_BALL);
    expect(snapshot.quickActions.length).assertEqual(2);
    expect(snapshot.nextScheduleText.length > 0).assertTrue();
  });

  it('maps play state to playful sprite and text', 0, () => {
    const snapshot = buildSnapshotForTest(defaultSchedule(), '2026-05-06T08:30:00');

    expect(snapshot.spriteState).assertEqual('playful');
    expect(snapshot.displayText).assertEqual('正在玩球');
    expect(snapshot.quickActions[0].id).assertEqual('feed');
    expect(snapshot.quickActions[1].id).assertEqual('play');
  });

  it('exposes the minimum service card quick actions contract', 0, () => {
    const snapshot = buildSnapshotForTest(defaultSchedule(), '2026-05-06T08:30:00');

    expect(snapshot.quickActions.length).assertEqual(2);
    expect(snapshot.quickActions[0].label).assertEqual('喂一下');
    expect(snapshot.quickActions[1].label).assertEqual('玩一下');
  });

  it('maps sleep state to a card-friendly preview snapshot', 0, () => {
    const snapshot = buildSurfaceSnapshot({
      pet: createPetSnapshot(PetAction.SLEEP, PetMood.SLEEPY),
      skin: defaultSkinProfile('default', '小橘'),
      schedule: defaultSchedule(),
      now: new Date('2026-05-06T08:30:00'),
    });

    expect(snapshot.displayText).assertEqual('正在睡觉');
    expect(snapshot.spriteState).assertEqual('sleep');
  });

  it('maps idle calm state to a stable fallback display text', 0, () => {
    const snapshot = buildSurfaceSnapshot({
      pet: createPetSnapshot(PetAction.IDLE, PetMood.CALM),
      skin: defaultSkinProfile('default', '小橘'),
      schedule: defaultSchedule(),
      now: new Date('2026-05-06T08:30:00'),
    });

    expect(snapshot.displayText).assertEqual('我在这儿');
  });

  it('provides lightweight text suitable for lock-screen display', 0, () => {
    const snapshot = buildSurfaceSnapshot({
      pet: createPetSnapshot(PetAction.SUNBATHE, PetMood.CALM),
      skin: defaultSkinProfile('default', '小橘'),
      schedule: defaultSchedule(),
      now: new Date('2026-05-06T15:00:00'),
    });

    expect(snapshot.displayText.length > 0).assertTrue();
    expect(snapshot.displayText.length <= 12).assertTrue();
  });

  it('adds weekday context for the next weekday-only rule', 0, () => {
    const snapshot = buildSnapshotForTest(createSchedule([
      {
        id: 'weekly-play',
        hour: 9,
        minute: 0,
        action: PetAction.PLAY_BALL,
        reason: '每周玩球',
        enabled: true,
        weekdays: [1],
      },
    ]), '2026-05-06T08:30:00');

    expect(snapshot.nextScheduleText).assertEqual('周一 09:00 - 每周玩球');
  });

  it('returns empty nextScheduleText when all rules are disabled', 0, () => {
    const snapshot = buildSnapshotForTest(createSchedule([
      {
        id: 'disabled-feed',
        hour: 9,
        minute: 0,
        action: PetAction.EAT,
        reason: '早餐',
        enabled: false,
        weekdays: [],
      },
    ]), '2026-05-06T08:30:00');

    expect(snapshot.nextScheduleText).assertEqual('');
  });

  it('returns empty nextScheduleText when the schedule is empty', 0, () => {
    const snapshot = buildSnapshotForTest(createSchedule([]), '2026-05-06T08:30:00');

    expect(snapshot.nextScheduleText).assertEqual('');
  });

  it('treats a rule at the current minute as already started', 0, () => {
    const snapshot = buildSnapshotForTest(defaultSchedule(), '2026-05-06T09:00:00');

    expect(snapshot.nextScheduleText).assertEqual('12:00 - 午饭时间到');
  });
});
