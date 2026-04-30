import { describe, it, expect } from '@ohos/hypium';

import { PetEvent } from '../../../main/ets/common/models/PetState';
import {
  clearQuickActionFeedback,
  currentQuickActionFeedback,
  handleQuickAction,
  handleQuickActionWithFeedback,
  isQuickActionId,
  quickActionToEvent,
} from '../../../main/ets/common/services/PetQuickActionService';
import { PetEngine } from '../../../main/ets/features/pet3d/PetEngine';

describe('PetQuickActionService', () => {
  it('maps feed quick action to feed event', 0, () => {
    const event = quickActionToEvent('feed');

    expect(event.type).assertEqual('user_feed_bone');
  });

  it('maps play quick action to play event', 0, () => {
    const event = quickActionToEvent('play');

    expect(event.type).assertEqual('user_play_ball');
  });

  it('recognizes supported quick action ids', 0, () => {
    expect(isQuickActionId('feed')).assertTrue();
    expect(isQuickActionId('play')).assertTrue();
    expect(isQuickActionId('dance')).assertFalse();
  });

  it('dispatches a valid raw action through PetEngine', 0, () => {
    const engine = PetEngine.instance();
    const originalDispatch = engine.dispatch;
    let dispatched: PetEvent | undefined = undefined;
    const action: string = 'feed';

    engine.dispatch = (event: PetEvent): void => {
      dispatched = event;
    };

    try {
      const handled = handleQuickAction(action);

      expect(handled).assertTrue();
    } finally {
      engine.dispatch = originalDispatch;
    }

    expect(!!dispatched).assertTrue();
    expect(dispatched?.type ?? '').assertEqual('user_feed_bone');
  });

  it('stores short-lived feedback for a valid quick action', 0, () => {
    clearQuickActionFeedback();

    const result = handleQuickActionWithFeedback('feed', 1_000);

    expect(result.handled).assertTrue();
    expect(result.feedbackText ?? '').assertEqual('吃饱啦');
    expect(currentQuickActionFeedback(1_000) ?? '').assertEqual('吃饱啦');
    expect(currentQuickActionFeedback(3_001) ?? '').assertEqual('');
  });

  it('makes feedback visible during synchronous dispatch refreshes', 0, () => {
    clearQuickActionFeedback();

    const engine = PetEngine.instance();
    const originalDispatch = engine.dispatch;
    let feedbackSeenDuringDispatch: string = '';

    engine.dispatch = (_event: PetEvent): void => {
      feedbackSeenDuringDispatch = currentQuickActionFeedback(1_000) ?? '';
    };

    try {
      const result = handleQuickActionWithFeedback('feed', 1_000);

      expect(result.handled).assertTrue();
    } finally {
      engine.dispatch = originalDispatch;
      clearQuickActionFeedback();
    }

    expect(feedbackSeenDuringDispatch).assertEqual('吃饱啦');
  });

  it('rejects an invalid raw action without dispatching', 0, () => {
    const engine = PetEngine.instance();
    const originalDispatch = engine.dispatch;
    let dispatchCount = 0;
    const action: string = 'dance';

    engine.dispatch = (_event: PetEvent): void => {
      dispatchCount += 1;
    };

    try {
      const handled = handleQuickAction(action);

      expect(handled).assertFalse();
    } finally {
      engine.dispatch = originalDispatch;
    }

    expect(dispatchCount).assertEqual(0);
  });

  it('does not create feedback for an invalid raw action', 0, () => {
    clearQuickActionFeedback();

    const result = handleQuickActionWithFeedback('dance', 1_000);

    expect(result.handled).assertFalse();
    expect(currentQuickActionFeedback(1_000) ?? '').assertEqual('');
  });
});
