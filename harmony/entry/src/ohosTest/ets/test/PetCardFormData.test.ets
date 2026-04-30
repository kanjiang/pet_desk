import { describe, it, expect } from '@ohos/hypium';

import { PetAction, PetMood } from '../../../main/ets/common/models/PetState';
import { PetSurfaceSnapshot } from '../../../main/ets/common/models/PetSurfaceSnapshot';
import { toPetCardFormData } from '../../../main/ets/features/form/PetCardFormData';

function createSurfaceSnapshot(displayText: string = '正在玩球'): PetSurfaceSnapshot {
  return {
    petName: '小橘',
    petMood: PetMood.PLAYFUL,
    currentAction: PetAction.PLAY_BALL,
    displayText,
    nextScheduleText: '12:00 - 午饭时间到',
    spriteState: 'playful',
    quickActions: [
      { id: 'feed', label: '喂一下', icon: 'feed', enabled: true },
      { id: 'play', label: '玩一下', icon: 'play', enabled: true },
    ],
    updatedAt: 123,
  };
}

describe('PetCardFormData', () => {
  it('falls back to a stable primary text when snapshot display text is blank', 0, () => {
    const formData = toPetCardFormData(createSurfaceSnapshot(''));

    expect(formData.displayText as string).assertEqual('我在这儿');
  });

  it('prefers temporary quick action feedback over snapshot display text', 0, () => {
    const formData = toPetCardFormData(createSurfaceSnapshot('正在玩球'), '吃饱啦');

    expect(formData.displayText as string).assertEqual('吃饱啦');
  });
});
