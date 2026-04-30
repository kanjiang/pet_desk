/**
 * 宠物状态机的核心模型.
 *
 * 设计原则:
 * - 单一事实源: 整个 App 通过 PetEngine.subscribe / @StorageLink 订阅 PetState
 * - 不可变更新: 所有状态变更通过 dispatch(event) 而非直接 set
 * - UI 与渲染层只读
 *
 * 模块依赖:
 * - 本文件不能 import scheduler 模块, 否则循环依赖 (Scheduler -> PetEngine -> PetState).
 * - 所以 schedule_fire 事件只引用最小子集 ScheduleFireRef (action + reason),
 *   Scheduler 在派发时把 ScheduleRule 拍扁成 ScheduleFireRef.
 */

export enum PetAction {
  IDLE = 'idle',
  WALK = 'walk',
  SIT = 'sit',
  SLEEP = 'sleep',
  EAT = 'eat',
  PLAY_BALL = 'play_ball',
  PLAY_TOY = 'play_toy',
  SCRATCH = 'scratch',
  HAPPY_JUMP = 'happy_jump',
  STRETCH = 'stretch',
  SUNBATHE = 'sunbathe',
  COMFORT = 'comfort',
}

export enum PetMood {
  HAPPY = 'happy',
  CALM = 'calm',
  SLEEPY = 'sleepy',
  HUNGRY = 'hungry',
  PLAYFUL = 'playful',
  CONCERNED = 'concerned',
}

export interface ScheduleFireRef {
  ruleId: string;
  action: PetAction;
  reason: string;
}

export interface PetSnapshot {
  petId: string;
  action: PetAction;
  mood: PetMood;
  energy: number;
  hunger: number;
  affection: number;
  lastInteractionAt: number;
  lastActionSource: 'user' | 'schedule' | 'mood' | 'system';
  updatedAt: number;
}

export type PetEvent =
  | { type: 'user_pet' }
  | { type: 'user_play_ball' }
  | { type: 'user_play_toy' }
  | { type: 'user_feed_bone' }
  | { type: 'user_send_to_sleep' }
  | { type: 'user_scratch' }
  | { type: 'user_sunbathe' }
  | { type: 'user_stretch' }
  | { type: 'scheduler_tick'; clock: number }
  | { type: 'schedule_fire'; rule: ScheduleFireRef }
  | { type: 'mood_signal'; level: 'low' | 'stressed' | 'relaxed' };

export const DEFAULT_SNAPSHOT: PetSnapshot = {
  petId: 'default',
  action: PetAction.IDLE,
  mood: PetMood.CALM,
  energy: 80,
  hunger: 30,
  affection: 50,
  lastInteractionAt: 0,
  lastActionSource: 'system',
  updatedAt: 0,
};
