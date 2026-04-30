import { QuickActionId } from '../models/PetSurfaceSnapshot';
import { PetEvent } from '../models/PetState';
import { PetQuickActionFeedbackStore, QuickActionFeedbackState } from './PetQuickActionFeedbackStore';
import { PetEngine } from '../../features/pet3d/PetEngine';

const SUPPORTED_QUICK_ACTIONS: Record<QuickActionId, true> = {
  feed: true,
  play: true,
};
const QUICK_ACTION_FEEDBACK_DURATION_MS: number = 2_000;
const QUICK_ACTION_FEEDBACK_TEXT: Record<QuickActionId, string> = {
  feed: '吃饱啦',
  play: '好开心',
};

export interface QuickActionFeedbackResult {
  handled: boolean;
  feedbackText?: string;
  expiresAt?: number;
}

export function quickActionToEvent(action: QuickActionId): PetEvent {
  switch (action) {
    case 'feed':
      return { type: 'user_feed_bone' };
    case 'play':
      return { type: 'user_play_ball' };
    default:
      return assertUnreachableQuickAction(action);
  }
}

export function isQuickActionId(action: string): action is QuickActionId {
  return Object.prototype.hasOwnProperty.call(SUPPORTED_QUICK_ACTIONS, action);
}

export function handleQuickAction(action: string): boolean {
  if (!isQuickActionId(action)) {
    return false;
  }

  PetEngine.instance().dispatch(quickActionToEvent(action));
  return true;
}

export function handleQuickActionWithFeedback(action: string, nowMs: number = Date.now()): QuickActionFeedbackResult {
  if (!isQuickActionId(action)) {
    return { handled: false };
  }

  const feedbackText: string = QUICK_ACTION_FEEDBACK_TEXT[action];
  const expiresAt: number = nowMs + QUICK_ACTION_FEEDBACK_DURATION_MS;
  const feedback: QuickActionFeedbackState = {
    text: feedbackText,
    expiresAt,
  };
  PetQuickActionFeedbackStore.instance().set(feedback);
  PetEngine.instance().dispatch(quickActionToEvent(action));
  return {
    handled: true,
    feedbackText,
    expiresAt,
  };
}

export function currentQuickActionFeedback(nowMs: number = Date.now()): string | undefined {
  return PetQuickActionFeedbackStore.instance().current(nowMs);
}

export function clearQuickActionFeedback(): void {
  PetQuickActionFeedbackStore.instance().clear();
}

function assertUnreachableQuickAction(action: never): never {
  throw new Error(`Unhandled QuickActionId: ${String(action)}`);
}
