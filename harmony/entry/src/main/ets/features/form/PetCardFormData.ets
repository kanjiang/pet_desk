import { PetSurfaceSnapshot, QuickActionDescriptor, QuickActionId } from '../../common/models/PetSurfaceSnapshot';

export type PetCardBindingValue = string | number;

export const DEFAULT_FEED_LABEL: string = '喂一下';
export const DEFAULT_PLAY_LABEL: string = '玩一下';
export const DEFAULT_CARD_DISPLAY_TEXT: string = '我在这儿';

export interface PetCardFormData {
  petName: string;
  displayText: string;
  nextScheduleText: string;
  feedAction: string;
  feedLabel: string;
  playAction: string;
  playLabel: string;
  updatedAt: number;
}

export function toPetCardFormData(
  snapshot: PetSurfaceSnapshot,
  quickActionFeedbackText?: string,
): Record<string, PetCardBindingValue> {
  return {
    petName: snapshot.petName,
    displayText: primaryDisplayText(snapshot, quickActionFeedbackText),
    nextScheduleText: snapshot.nextScheduleText,
    feedAction: 'feed',
    feedLabel: actionLabel(snapshot.quickActions, 'feed', DEFAULT_FEED_LABEL),
    playAction: 'play',
    playLabel: actionLabel(snapshot.quickActions, 'play', DEFAULT_PLAY_LABEL),
    updatedAt: snapshot.updatedAt,
  };
}

function primaryDisplayText(snapshot: PetSurfaceSnapshot, quickActionFeedbackText?: string): string {
  const feedbackText: string | undefined = normalizedText(quickActionFeedbackText);
  if (feedbackText !== undefined) {
    return feedbackText;
  }

  const snapshotText: string | undefined = normalizedText(snapshot.displayText);
  if (snapshotText !== undefined) {
    return snapshotText;
  }

  return DEFAULT_CARD_DISPLAY_TEXT;
}

function normalizedText(text?: string): string | undefined {
  if (typeof text !== 'string') {
    return undefined;
  }

  const trimmed: string = text.trim();
  if (trimmed.length === 0) {
    return undefined;
  }

  return trimmed;
}

function actionLabel(actions: QuickActionDescriptor[], actionId: QuickActionId, fallback: string): string {
  const target: QuickActionDescriptor | undefined = actions.find((action) => action.id === actionId);
  return target?.label ?? fallback;
}
