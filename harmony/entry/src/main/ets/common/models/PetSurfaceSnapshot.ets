import { PetAction, PetMood } from './PetState';

export type QuickActionId = 'feed' | 'play';

export interface QuickActionDescriptor {
  id: QuickActionId;
  label: string;
  icon: string;
  enabled: boolean;
}

export interface PetSurfaceSnapshot {
  petName: string;
  petMood: PetMood;
  currentAction: PetAction;
  displayText: string;
  nextScheduleText: string;
  spriteState: string;
  quickActions: QuickActionDescriptor[];
  updatedAt: number;
}
