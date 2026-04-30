import { PetAction, PetMood, PetSnapshot } from '../models/PetState';
import { PetSurfaceSnapshot, QuickActionDescriptor } from '../models/PetSurfaceSnapshot';
import { SkinProfile } from '../models/SkinProfile';
import { DailySchedule, ScheduleRule } from '../../features/scheduler/ScheduleRule';

export interface BuildSurfaceInput {
  pet: PetSnapshot;
  skin: SkinProfile;
  schedule: DailySchedule;
  now?: Date;
}

interface NextScheduleOccurrence {
  rule: ScheduleRule;
  when: Date;
}

const QUICK_ACTIONS: QuickActionDescriptor[] = [
  { id: 'feed', label: '喂一下', icon: 'feed', enabled: true },
  { id: 'play', label: '玩一下', icon: 'play', enabled: true },
];

export function buildSurfaceSnapshot(input: BuildSurfaceInput): PetSurfaceSnapshot {
  const now: Date = input.now ?? new Date();
  const nextRule: NextScheduleOccurrence | null = nextScheduleRule(input.schedule, now);

  return {
    petName: input.skin.petName,
    petMood: input.pet.mood,
    currentAction: input.pet.action,
    displayText: displayTextForAction(input.pet.action, input.pet.mood),
    nextScheduleText: nextRule === null ? '' : formatNextScheduleText(nextRule, now),
    spriteState: spriteStateForAction(input.pet.action, input.pet.mood),
    quickActions: QUICK_ACTIONS.map((action) => ({ ...action })),
    updatedAt: now.getTime(),
  };
}

function displayTextForAction(action: PetAction, mood: PetMood): string {
  switch (action) {
    case PetAction.IDLE:
      return displayTextForIdleMood(mood);
    case PetAction.WALK:
      return '正在散步';
    case PetAction.SIT:
      return '正在坐着';
    case PetAction.SLEEP:
      return '正在睡觉';
    case PetAction.EAT:
      return '正在吃饭';
    case PetAction.PLAY_BALL:
      return '正在玩球';
    case PetAction.PLAY_TOY:
      return '正在玩耍';
    case PetAction.SCRATCH:
      return '正在抓抓板';
    case PetAction.HAPPY_JUMP:
      return '开心跳跳';
    case PetAction.STRETCH:
      return '正在伸懒腰';
    case PetAction.SUNBATHE:
      return '正在晒太阳';
    case PetAction.COMFORT:
      return '正在被安抚';
    default:
      return assertUnreachableAction(action);
  }
}

function displayTextForIdleMood(mood: PetMood): string {
  switch (mood) {
    case PetMood.HAPPY:
      return '今天很开心';
    case PetMood.CALM:
      return '我在这儿';
    case PetMood.SLEEPY:
      return '有点困了';
    case PetMood.HUNGRY:
      return '有点饿了';
    case PetMood.PLAYFUL:
      return '想一起玩';
    case PetMood.CONCERNED:
      return '想要你陪陪';
    default:
      return assertUnreachableMood(mood);
  }
}

function spriteStateForAction(action: PetAction, mood: PetMood): string {
  switch (action) {
    case PetAction.IDLE:
      return spriteStateForIdleMood(mood);
    case PetAction.WALK:
      return 'walk';
    case PetAction.SIT:
      return 'sit';
    case PetAction.SLEEP:
      return 'sleep';
    case PetAction.EAT:
      return 'eat';
    case PetAction.PLAY_BALL:
    case PetAction.PLAY_TOY:
    case PetAction.HAPPY_JUMP:
      return 'playful';
    case PetAction.SCRATCH:
      return 'scratch';
    case PetAction.STRETCH:
      return 'stretch';
    case PetAction.SUNBATHE:
      return 'sunbathe';
    case PetAction.COMFORT:
      return 'comfort';
    default:
      return assertUnreachableAction(action);
  }
}

function spriteStateForIdleMood(mood: PetMood): string {
  switch (mood) {
    case PetMood.HAPPY:
    case PetMood.CALM:
    case PetMood.HUNGRY:
    case PetMood.CONCERNED:
      return 'idle';
    case PetMood.SLEEPY:
      return 'sleep';
    case PetMood.PLAYFUL:
      return 'playful';
    default:
      return assertUnreachableMood(mood);
  }
}

function nextScheduleRule(schedule: DailySchedule, from: Date): NextScheduleOccurrence | null {
  let bestRule: NextScheduleOccurrence | null = null;
  let bestWhenMs: number = Number.MAX_SAFE_INTEGER;

  for (const rule of schedule.rules) {
    if (!rule.enabled) {
      continue;
    }

    const candidate: Date = nextRuleDate(rule, from);
    const candidateMs: number = candidate.getTime();
    if (candidateMs < bestWhenMs) {
      bestRule = { rule, when: candidate };
      bestWhenMs = candidateMs;
    }
  }

  return bestRule;
}

function nextRuleDate(rule: ScheduleRule, from: Date): Date {
  const candidate: Date = new Date(from.getFullYear(), from.getMonth(), from.getDate(), rule.hour, rule.minute, 0, 0);

  for (let dayOffset = 0; dayOffset < 8; dayOffset++) {
    const probe: Date = new Date(candidate.getTime());
    probe.setDate(candidate.getDate() + dayOffset);

    if (probe.getTime() <= from.getTime()) {
      continue;
    }

    const weekday: number = probe.getDay();
    if (rule.weekdays.length > 0 && !rule.weekdays.includes(weekday)) {
      continue;
    }

    return probe;
  }

  const fallback: Date = new Date(candidate.getTime());
  fallback.setDate(candidate.getDate() + 7);
  return fallback;
}

function pad2(value: number): string {
  return String(value).padStart(2, '0');
}

function formatNextScheduleText(next: NextScheduleOccurrence, now: Date): string {
  const timeText: string = `${pad2(next.when.getHours())}:${pad2(next.when.getMinutes())}`;
  const dayOffset: number = daysBetweenLocalDates(now, next.when);

  if (dayOffset === 0) {
    return `${timeText} - ${next.rule.reason}`;
  }

  if (dayOffset === 1) {
    return `明天 ${timeText} - ${next.rule.reason}`;
  }

  return `${weekdayLabel(next.when.getDay())} ${timeText} - ${next.rule.reason}`;
}

function daysBetweenLocalDates(from: Date, to: Date): number {
  const fromStart: Date = new Date(from.getFullYear(), from.getMonth(), from.getDate());
  const toStart: Date = new Date(to.getFullYear(), to.getMonth(), to.getDate());
  const dayMs: number = 24 * 60 * 60 * 1000;
  return Math.round((toStart.getTime() - fromStart.getTime()) / dayMs);
}

function weekdayLabel(weekday: number): string {
  const labels: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return labels[weekday] ?? '周?';
}

function assertUnreachableAction(action: never): never {
  throw new Error(`Unhandled PetAction: ${String(action)}`);
}

function assertUnreachableMood(mood: never): never {
  throw new Error(`Unhandled PetMood: ${String(mood)}`);
}
