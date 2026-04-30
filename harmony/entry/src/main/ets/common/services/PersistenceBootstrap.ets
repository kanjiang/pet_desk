/**
 * 持久化层启动器 - 在 EntryAbility.onCreate 调用一次, 集中初始化所有需要 context 的存储模块.
 *
 * 当前覆盖:
 *   - SkinRepo (Preferences)
 *   - ScheduleRepo (Preferences)
 *
 * 后续 (M3) 加入时, 在这里 add line 即可, 上层 ability 不用改.
 */

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { PetFormRegistry } from './PetFormRegistry';
import { PetQuickActionFeedbackStore } from './PetQuickActionFeedbackStore';
import { MoodStateRepo } from '../../features/mood/MoodStateRepo';
import { SkinRepo } from '../../features/storage/SkinRepo';
import { ScheduleRepo } from '../../features/scheduler/ScheduleRepo';

const TAG: string = 'PetDesk.PersistenceBootstrap';
const DOMAIN: number = 0xC001;

export async function bootstrapPersistence(context: common.Context): Promise<void> {
  hilog.info(DOMAIN, TAG, 'starting');
  await Promise.all([
    PetFormRegistry.instance().init(context),
    PetQuickActionFeedbackStore.instance().init(context),
    MoodStateRepo.instance().init(context),
    SkinRepo.instance().init(context),
    ScheduleRepo.instance().init(context),
  ]);
  hilog.info(DOMAIN, TAG, 'done');
}
