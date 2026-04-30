/**
 * Scheduler v2 - 基于真实时钟的作息调度器.
 *
 * 每 30s tick 一次, 做两件事:
 *   1. 给 PetEngine 派发 'scheduler_tick' (能量/饥饿衰减用)
 *   2. 扫描当前作息表, 命中的规则派发 'schedule_fire'
 *
 * 防抖:
 *   - firedKey = ruleId + ':' + dateKey + ':' + HH:MM
 *   - 1 个 tick 命中后, 同 firedKey 在 60s 内不再触发
 *   - 即使 tick 漂移到下一个 30s 槽, 也只会触发一次
 *
 * 为什么 30s 而不是 60s:
 *   即使一次 tick 错过了精确分钟整点 (eg. 12:00:31), 下一次 tick 还能命中同一分钟内.
 *
 * 为什么不用系统 cron:
 *   鸿蒙没有跨进程 cron; M2 阶段在 App 进程内用 setInterval, M3 后台 Ability 上线再迁.
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

import { ScheduleFireRef } from '../../common/models/PetState';
import { PetEngine } from '../pet3d/PetEngine';
import { ScheduleRepo } from './ScheduleRepo';
import { rulesActiveAt, ScheduleRule } from './ScheduleRule';

const TAG: string = 'PetDesk.Scheduler';
const DOMAIN: number = 0xC001;

const TICK_MS: number = 30_000;
const FIRE_GUARD_MS: number = 60_000;

export interface NextOccurrence {
  rule: ScheduleRule;
  whenMs: number;
}

export class Scheduler {
  private static _instance: Scheduler | undefined;
  private timer: number = -1;
  private fired: Map<string, number> = new Map();

  static instance(): Scheduler {
    if (!Scheduler._instance) {
      Scheduler._instance = new Scheduler();
    }
    return Scheduler._instance;
  }

  start(intervalMs: number = TICK_MS): void {
    if (this.timer !== -1) {
      return;
    }
    this.tick();
    this.timer = setInterval(() => this.tick(), intervalMs);
    hilog.info(DOMAIN, TAG, 'started');
  }

  stop(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
      hilog.info(DOMAIN, TAG, 'stopped');
    }
  }

  /** 给 UI 用的"下一项作息" 查询. 不受防抖表影响, 仅看规则定义本身. */
  nextOccurrence(now: Date = new Date()): NextOccurrence | null {
    const sched = ScheduleRepo.instance().current();
    let best: NextOccurrence | null = null;
    for (const r of sched.rules) {
      if (!r.enabled) continue;
      const when: number = nextFireDate(r, now).getTime();
      if (best === null || when < best.whenMs) {
        best = { rule: r, whenMs: when };
      }
    }
    return best;
  }

  /** 测试/调试用: 立即触发某规则, 不受防抖表限制. */
  triggerNow(rule: ScheduleRule): void {
    PetEngine.instance().dispatch({ type: 'schedule_fire', rule: toRef(rule) });
  }

  private tick(): void {
    const now: Date = new Date();
    PetEngine.instance().dispatch({ type: 'scheduler_tick', clock: now.getTime() });

    const sched = ScheduleRepo.instance().current();
    const hits: ScheduleRule[] = rulesActiveAt(sched, now.getHours(), now.getMinutes(), now.getDay());
    if (hits.length === 0) {
      return;
    }
    const dateKey: string = `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;
    const hm: string = `${now.getHours()}:${now.getMinutes()}`;
    for (const rule of hits) {
      const key: string = `${rule.id}:${dateKey}:${hm}`;
      const last: number | undefined = this.fired.get(key);
      if (last !== undefined && now.getTime() - last < FIRE_GUARD_MS) {
        continue;
      }
      this.fired.set(key, now.getTime());
      hilog.info(DOMAIN, TAG, 'fire rule %{public}s -> %{public}s', rule.id, rule.action);
      PetEngine.instance().dispatch({ type: 'schedule_fire', rule: toRef(rule) });
    }
    this.evictOldFiredKeys(now.getTime());
  }

  private evictOldFiredKeys(nowMs: number): void {
    const cutoff: number = nowMs - 24 * 60 * 60 * 1000;
    for (const [k, v] of this.fired) {
      if (v < cutoff) {
        this.fired.delete(k);
      }
    }
  }
}

function toRef(rule: ScheduleRule): ScheduleFireRef {
  return { ruleId: rule.id, action: rule.action, reason: rule.reason };
}

function nextFireDate(rule: ScheduleRule, from: Date): Date {
  const candidate: Date = new Date(from.getFullYear(), from.getMonth(), from.getDate(), rule.hour, rule.minute, 0, 0);
  for (let dayOffset: number = 0; dayOffset < 8; dayOffset++) {
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
  return candidate;
}
