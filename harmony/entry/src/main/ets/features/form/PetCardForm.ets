import { postCardAction } from '@kit.FormKit';

import { DEFAULT_SURFACE_SNAPSHOT } from '../../common/services/PetSurfacePublisher';
import { DEFAULT_FEED_LABEL, DEFAULT_PLAY_LABEL } from './PetCardFormData';

const OPEN_APP_SOURCE: string = 'pet_service_card';

export const petCardStorage: LocalStorage = new LocalStorage();

@Entry(petCardStorage)
@Component
struct PetCardForm {
  @LocalStorageProp('petName') petName: string = DEFAULT_SURFACE_SNAPSHOT.petName;
  @LocalStorageProp('displayText') displayText: string = DEFAULT_SURFACE_SNAPSHOT.displayText;
  @LocalStorageProp('nextScheduleText') nextScheduleText: string = DEFAULT_SURFACE_SNAPSHOT.nextScheduleText;
  @LocalStorageProp('feedAction') feedAction: string = 'feed';
  @LocalStorageProp('feedLabel') feedLabel: string = DEFAULT_FEED_LABEL;
  @LocalStorageProp('playAction') playAction: string = 'play';
  @LocalStorageProp('playLabel') playLabel: string = DEFAULT_PLAY_LABEL;

  build() {
    Column({ space: 12 }) {
      Column({ space: 6 }) {
        Row() {
          Column({ space: 4 }) {
            Text(this.petName)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#2A1F1A')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            Text(this.displayText)
              .fontSize(14)
              .fontColor('#5F4A42')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            Text(this.scheduleSummary())
              .fontSize(12)
              .fontColor('#8A5B4A')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .alignItems(HorizontalAlign.Start);

          Blank();

          Text('打开')
            .fontSize(12)
            .fontColor('#FF8A5C');
        }
        .width('100%');
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      .backgroundColor('#FFF4EE')
      .borderRadius(18)
      .onClick(() => this.openApp());

      Row({ space: 10 }) {
        Button(this.feedLabel)
          .layoutWeight(1)
          .height(40)
          .backgroundColor('#FF8A5C')
          .fontColor('#FFFFFF')
          .borderRadius(14)
          .onClick(() => this.sendQuickAction(this.feedAction));
        Button(this.playLabel)
          .layoutWeight(1)
          .height(40)
          .backgroundColor('#2A1F1A')
          .fontColor('#FFFFFF')
          .borderRadius(14)
          .onClick(() => this.sendQuickAction(this.playAction));
      }
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#FFF8F0');
  }

  private scheduleSummary(): string {
    if (this.nextScheduleText.length > 0) {
      return `下一项: ${this.nextScheduleText}`;
    }
    return '下一项: 暂无安排';
  }

  private openApp(): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: {
        source: OPEN_APP_SOURCE,
      },
    });
  }

  private sendQuickAction(action: string): void {
    postCardAction(this, {
      action: 'message',
      params: {
        action,
      },
    });
  }
}
