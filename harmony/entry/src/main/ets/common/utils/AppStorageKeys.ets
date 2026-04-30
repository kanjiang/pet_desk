/**
 * AppStorage / LocalStorage 键名常量, 避免到处出现魔法字符串.
 *
 * 约定:
 *   - skin:<petId>     -> SkinProfile 对象
 *   - schedule:default -> DailySchedule
 *   - mood:current     -> 最新一次 MoodReading (M3)
 *   - surface:default  -> PetSurfaceSnapshot
 *   - liveview:default -> PetSurfaceSnapshot
 */

export const KEY_DEFAULT_PET_ID: string = 'default';

export function skinKey(petId: string): string {
  return `skin:${petId}`;
}

export const KEY_SCHEDULE_DEFAULT: string = 'schedule:default';
export const KEY_MOOD_CURRENT: string = 'mood:current';
export const KEY_MOOD_BASELINE: string = 'mood:baseline';
export const KEY_SURFACE_DEFAULT: string = 'surface:default';
export const KEY_LIVEVIEW_DEFAULT: string = 'liveview:default';
