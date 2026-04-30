/**
 * 设置页 (M2) - 列出当前作息表, 支持开关单条规则与"立即触发"调试.
 *
 * 编辑时间/新增/删除规则在 M2.1 加 (ScheduleEditor 弹窗).
 */

import { router, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { Scheduler } from '../features/scheduler/Scheduler';
import { ScheduleRepo } from '../features/scheduler/ScheduleRepo';
import { DailySchedule, defaultSchedule, ScheduleRule } from '../features/scheduler/ScheduleRule';
import { KEY_SCHEDULE_DEFAULT } from '../common/utils/AppStorageKeys';

const TAG: string = 'PetDesk.Settings';
const DOMAIN: number = 0xC001;

@Entry
@Component
struct Settings {
  @StorageLink(KEY_SCHEDULE_DEFAULT) schedule: DailySchedule = defaultSchedule();

  private goBack(): void {
    try {
      router.back();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'router.back err: %{public}s', String(err));
    }
  }

  private toggleRule(ruleId: string, enabled: boolean): void {
    const next: DailySchedule = {
      ...this.schedule,
      rules: this.schedule.rules.map((r) => r.id === ruleId ? { ...r, enabled } : r),
    };
    ScheduleRepo.instance().save(next);
  }

  private restoreDefaults(): void {
    ScheduleRepo.instance().save(defaultSchedule());
    promptAction.showToast({ message: '已恢复默认作息' });
  }

  private triggerNow(rule: ScheduleRule): void {
    Scheduler.instance().triggerNow(rule);
    promptAction.showToast({ message: `已触发: ${rule.reason}` });
  }

  build() {
    Column() {
      this.topBar();
      this.intro();
      Scroll() {
        Column() {
          ForEach(this.schedule.rules, (r: ScheduleRule) => {
            this.ruleRow(r);
          }, (r: ScheduleRule) => r.id);
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .width('100%');
      }
      .layoutWeight(1)
      .width('100%');

      Button('恢复默认作息')
        .width('90%')
        .height(44)
        .margin({ bottom: 24 })
        .backgroundColor('#FFFFFF')
        .fontColor('#FF8A5C')
        .borderColor('#FF8A5C')
        .borderWidth(1)
        .borderRadius(14)
        .onClick(() => this.restoreDefaults());
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF8F0');
  }

  @Builder
  topBar() {
    Row() {
      Text('< 返回')
        .fontSize(14)
        .fontColor('#FF8A5C')
        .onClick(() => this.goBack());
      Blank();
      Text('作息表')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2A1F1A');
      Blank();
      Text('').width(48);
    }
    .width('100%')
    .padding({ top: 24, bottom: 12, left: 20, right: 20 });
  }

  @Builder
  intro() {
    Column() {
      Text('宠物会按下列时间自动做事. 可以单独关掉某项.')
        .fontSize(12)
        .fontColor('#888');
      Text('点 "试一下" 会立即触发, 适合调试.')
        .fontSize(11)
        .fontColor('#999')
        .margin({ top: 4 });
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 12 });
  }

  @Builder
  ruleRow(r: ScheduleRule) {
    Row() {
      Column() {
        Text(`${pad2(r.hour)}:${pad2(r.minute)}`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(r.enabled ? '#2A1F1A' : '#999');
        Text(r.action)
          .fontSize(10)
          .fontColor('#999');
      }
      .alignItems(HorizontalAlign.Start)
      .width(72);

      Column() {
        Text(r.reason)
          .fontSize(14)
          .fontColor(r.enabled ? '#2A1F1A' : '#999');
        if (r.weekdays.length > 0) {
          Text(`仅: ${r.weekdays.map(weekdayName).join('/')}`)
            .fontSize(10)
            .fontColor('#999')
            .margin({ top: 2 });
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .padding({ left: 8 });

      Text('试一下')
        .fontSize(11)
        .fontColor('#FF8A5C')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .borderRadius(10)
        .borderWidth(1)
        .borderColor('#FF8A5C')
        .margin({ right: 12 })
        .onClick(() => this.triggerNow(r));

      Toggle({ type: ToggleType.Switch, isOn: r.enabled })
        .onChange((on: boolean) => this.toggleRule(r.id, on));
    }
    .width('100%')
    .padding(14)
    .margin({ bottom: 8 })
    .backgroundColor('#FFFFFF')
    .borderRadius(14);
  }
}

function pad2(n: number): string {
  return String(n).padStart(2, '0');
}

function weekdayName(d: number): string {
  return ['日', '一', '二', '三', '四', '五', '六'][d] ?? '?';
}
