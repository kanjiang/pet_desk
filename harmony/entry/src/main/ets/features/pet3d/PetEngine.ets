/**
 * PetEngine - 宠物业务核心.
 *
 * 接收事件 -> 跑状态机 -> 广播新快照. UI 与渲染层只读订阅.
 *
 * M2 版本相比 M1 的变化:
 * - 互动行为从 4 个扩到 8 个 (撸/丢球/逗猫棒/喂骨头/睡觉/抓板/晒太阳/伸懒腰)
 * - 接受 Scheduler 派来的 schedule_fire 事件, 与用户事件统一走 reduce
 * - PetSnapshot.lastActionSource 标注当前动作来源 (UI 据此显示不同提示)
 * - scheduler_tick 衰减更细致, 并基于 hunger/energy 自动从 IDLE 过渡到 EAT/SLEEP
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  PetAction,
  PetEvent,
  PetMood,
  PetSnapshot,
  DEFAULT_SNAPSHOT,
} from '../../common/models/PetState';

const TAG: string = 'PetDesk.PetEngine';
const DOMAIN: number = 0xC001;

export type Listener = (snap: PetSnapshot) => void;

export class PetEngine {
  private static _instance: PetEngine | undefined;
  private snap: PetSnapshot = DEFAULT_SNAPSHOT;
  private listeners: Set<Listener> = new Set();

  static instance(): PetEngine {
    if (!PetEngine._instance) {
      PetEngine._instance = new PetEngine();
    }
    return PetEngine._instance;
  }

  current(): PetSnapshot {
    return this.snap;
  }

  subscribe(listener: Listener): () => void {
    this.listeners.add(listener);
    listener(this.snap);
    return () => {
      this.listeners.delete(listener);
    };
  }

  dispatch(event: PetEvent): void {
    const next: PetSnapshot = this.reduce(this.snap, event);
    if (next === this.snap) {
      return;
    }
    this.snap = next;
    hilog.info(DOMAIN, TAG, 'state -> action=%{public}s mood=%{public}s', next.action, next.mood);
    this.listeners.forEach((l) => l(next));
  }

  private reduce(s: PetSnapshot, e: PetEvent): PetSnapshot {
    const now: number = Date.now();
    switch (e.type) {
      case 'user_pet':
        return this.applyUserAction(s, PetAction.HAPPY_JUMP, PetMood.HAPPY, {
          affection: 5,
        });
      case 'user_play_ball':
        return this.applyUserAction(s, PetAction.PLAY_BALL, PetMood.PLAYFUL, {
          energy: -10,
          affection: 3,
        });
      case 'user_play_toy':
        return this.applyUserAction(s, PetAction.PLAY_TOY, PetMood.PLAYFUL, {
          energy: -8,
          affection: 4,
        });
      case 'user_feed_bone':
        return this.applyUserAction(s, PetAction.EAT, PetMood.HAPPY, {
          hunger: -30,
        });
      case 'user_send_to_sleep':
        return this.applyUserAction(s, PetAction.SLEEP, PetMood.SLEEPY, {
          energy: 20,
        });
      case 'user_scratch':
        return this.applyUserAction(s, PetAction.SCRATCH, PetMood.PLAYFUL, {
          energy: -3,
          affection: 1,
        });
      case 'user_sunbathe':
        return this.applyUserAction(s, PetAction.SUNBATHE, PetMood.CALM, {
          affection: 2,
        });
      case 'user_stretch':
        return this.applyUserAction(s, PetAction.STRETCH, PetMood.CALM, {
          energy: 3,
        });
      case 'schedule_fire':
        return {
          ...this.applyAction(s, e.rule.action, this.moodForAction(e.rule.action)),
          lastActionSource: 'schedule',
          lastInteractionAt: now,
          updatedAt: now,
        };
      case 'scheduler_tick':
        return this.applyTick(s, now);
      case 'mood_signal':
        if (e.level === 'low' || e.level === 'stressed') {
          return {
            ...s,
            action: PetAction.COMFORT,
            mood: PetMood.CONCERNED,
            lastInteractionAt: now,
            lastActionSource: 'mood',
            updatedAt: now,
          };
        }
        return s;
      default:
        return s;
    }
  }

  private applyUserAction(
    s: PetSnapshot,
    action: PetAction,
    mood: PetMood,
    delta: { energy?: number; hunger?: number; affection?: number },
  ): PetSnapshot {
    const now: number = Date.now();
    return {
      ...s,
      action,
      mood,
      energy: clamp(s.energy + (delta.energy ?? 0), 0, 100),
      hunger: clamp(s.hunger + (delta.hunger ?? 0), 0, 100),
      affection: clamp(s.affection + (delta.affection ?? 0), 0, 100),
      lastInteractionAt: now,
      lastActionSource: 'user',
      updatedAt: now,
    };
  }

  private applyAction(s: PetSnapshot, action: PetAction, mood: PetMood): PetSnapshot {
    const now: number = Date.now();
    let delta = { energy: 0, hunger: 0, affection: 0 };
    switch (action) {
      case PetAction.EAT:
        delta = { energy: 0, hunger: -25, affection: 0 };
        break;
      case PetAction.SLEEP:
        delta = { energy: 15, hunger: 0, affection: 0 };
        break;
      case PetAction.PLAY_BALL:
      case PetAction.PLAY_TOY:
        delta = { energy: -8, hunger: 0, affection: 1 };
        break;
      case PetAction.SCRATCH:
        delta = { energy: -2, hunger: 0, affection: 0 };
        break;
      case PetAction.STRETCH:
        delta = { energy: 3, hunger: 0, affection: 0 };
        break;
      case PetAction.SUNBATHE:
        delta = { energy: 0, hunger: 0, affection: 1 };
        break;
      default:
        break;
    }
    return {
      ...s,
      action,
      mood,
      energy: clamp(s.energy + delta.energy, 0, 100),
      hunger: clamp(s.hunger + delta.hunger, 0, 100),
      affection: clamp(s.affection + delta.affection, 0, 100),
      updatedAt: now,
    };
  }

  /**
   * Tick: 衰减 energy, 增加 hunger; 自动从 IDLE 过渡到 SLEEP/EAT.
   * 若处于用户/作息触发的非 IDLE 状态超过 90s, 也会自动回到 IDLE.
   */
  private applyTick(s: PetSnapshot, now: number): PetSnapshot {
    const energy: number = clamp(s.energy - 1, 0, 100);
    const hunger: number = clamp(s.hunger + 2, 0, 100);
    let action: PetAction = s.action;
    let mood: PetMood = s.mood;

    const sinceLast: number = now - s.lastInteractionAt;
    const idleNow: boolean = action === PetAction.IDLE;
    const lingering: boolean = sinceLast > 90_000 && !idleNow;

    if (lingering) {
      action = PetAction.IDLE;
      mood = PetMood.CALM;
    }

    if (action === PetAction.IDLE) {
      if (energy < 20) {
        action = PetAction.SLEEP;
        mood = PetMood.SLEEPY;
      } else if (hunger > 80) {
        action = PetAction.SIT;
        mood = PetMood.HUNGRY;
      }
    }

    return {
      ...s,
      energy,
      hunger,
      action,
      mood,
      updatedAt: now,
    };
  }

  private moodForAction(action: PetAction): PetMood {
    switch (action) {
      case PetAction.EAT: return PetMood.HAPPY;
      case PetAction.SLEEP: return PetMood.SLEEPY;
      case PetAction.PLAY_BALL:
      case PetAction.PLAY_TOY:
      case PetAction.SCRATCH:
        return PetMood.PLAYFUL;
      case PetAction.HAPPY_JUMP: return PetMood.HAPPY;
      case PetAction.STRETCH:
      case PetAction.SUNBATHE:
        return PetMood.CALM;
      case PetAction.COMFORT: return PetMood.CONCERNED;
      default: return PetMood.CALM;
    }
  }
}

function clamp(v: number, lo: number, hi: number): number {
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}
