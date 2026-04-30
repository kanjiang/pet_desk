/**
 * 作息规则模型 + 默认作息表.
 *
 * 设计要点:
 * - hour/minute 用本地时区, weekdays 用 0=周日..6=周六 的 ISO 习惯
 * - id 必须在一个 schedule 内唯一, 用户编辑/删除时按 id 定位
 * - reason 是给 UI 显示的人话, 不参与调度逻辑
 */

import { PetAction } from '../../common/models/PetState';

export interface ScheduleRule {
  id: string;
  hour: number;
  minute: number;
  action: PetAction;
  reason: string;
  enabled: boolean;
  weekdays: number[];
}

export interface DailySchedule {
  rules: ScheduleRule[];
  createdAt: number;
  updatedAt: number;
}

export const DEFAULT_RULES: ScheduleRule[] = [
  { id: 'morning_stretch', hour: 7, minute: 0, action: PetAction.HAPPY_JUMP, reason: '该起床啦, 伸个懒腰', enabled: true, weekdays: [] },
  { id: 'morning_play', hour: 9, minute: 0, action: PetAction.PLAY_BALL, reason: '上午精力旺, 玩会儿球', enabled: true, weekdays: [] },
  { id: 'lunch', hour: 12, minute: 0, action: PetAction.EAT, reason: '午饭时间到', enabled: true, weekdays: [] },
  { id: 'siesta', hour: 14, minute: 0, action: PetAction.SLEEP, reason: '午睡补补精力', enabled: true, weekdays: [] },
  { id: 'afternoon_scratch', hour: 17, minute: 0, action: PetAction.SCRATCH, reason: '抓抓板磨爪', enabled: true, weekdays: [] },
  { id: 'dinner', hour: 19, minute: 0, action: PetAction.EAT, reason: '晚饭', enabled: true, weekdays: [] },
  { id: 'evening_play', hour: 21, minute: 0, action: PetAction.PLAY_TOY, reason: '睡前活动一下', enabled: true, weekdays: [] },
  { id: 'bedtime', hour: 22, minute: 30, action: PetAction.SLEEP, reason: '该睡觉啦', enabled: true, weekdays: [] },
];

export function defaultSchedule(): DailySchedule {
  const now: number = Date.now();
  return {
    rules: DEFAULT_RULES.slice(),
    createdAt: now,
    updatedAt: now,
  };
}

/**
 * 给定 (hour, minute, weekday), 返回此刻应该触发的所有 enabled 规则.
 * weekday: 0=Sun..6=Sat
 */
export function rulesActiveAt(
  schedule: DailySchedule,
  hour: number,
  minute: number,
  weekday: number,
): ScheduleRule[] {
  const out: ScheduleRule[] = [];
  for (const r of schedule.rules) {
    if (!r.enabled) continue;
    if (r.hour !== hour || r.minute !== minute) continue;
    if (r.weekdays.length > 0 && !r.weekdays.includes(weekday)) continue;
    out.push(r);
  }
  return out;
}
