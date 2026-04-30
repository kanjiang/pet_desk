/**
 * 照片选择页 - 端到端: 选图 -> 提色 -> 预览色板 -> 应用到 SkinProfile.
 */

import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { promptAction, router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

import { BaseModelId } from '../common/models/SkinProfile';
import { KEY_DEFAULT_PET_ID } from '../common/utils/AppStorageKeys';
import { ExtractResult } from '../features/photo2skin/ColorExtractor';
import { buildSkinFromPhotos } from '../features/photo2skin/Photo2SkinService';
import { SkinRepo } from '../features/storage/SkinRepo';

const TAG: string = 'PetDesk.PhotoPick';
const DOMAIN: number = 0xC001;

interface BreedOption {
  id: BaseModelId;
  label: string;
}

const BREED_OPTIONS: BreedOption[] = [
  { id: 'shorthair_cat', label: '短毛猫' },
  { id: 'longhair_cat', label: '长毛猫' },
  { id: 'shiba', label: '柴犬' },
  { id: 'golden_retriever', label: '金毛' },
  { id: 'border_collie', label: '边牧' },
  { id: 'rabbit_lop', label: '垂耳兔' },
  { id: 'hamster', label: '仓鼠' },
];

@Entry
@Component
struct PhotoPick {
  @State private selectedUris: string[] = [];
  @State private breedIndex: number = 0;
  @State private petName: string = '我家宝贝';
  @State private busy: boolean = false;
  @State private palette: ExtractResult | null = null;
  @State private statusText: string = '';

  private async pickPhotos(): Promise<void> {
    try {
      const opts: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      opts.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      opts.maxSelectNumber = 5;
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(opts);
      this.selectedUris = result.photoUris ?? [];
      this.palette = null;
      this.statusText = `已选择 ${this.selectedUris.length} 张照片`;
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'picker err: %{public}s', e.message);
      this.statusText = '取消或选择失败';
    }
  }

  private async generateSkin(): Promise<void> {
    if (this.selectedUris.length === 0) {
      promptAction.showToast({ message: '请先选择至少 1 张照片' });
      return;
    }
    this.busy = true;
    this.statusText = '正在分析照片颜色...';
    try {
      await SkinRepo.instance().whenReady();
      const result = await buildSkinFromPhotos({
        petId: KEY_DEFAULT_PET_ID,
        petName: this.petName.trim().length === 0 ? '我家宝贝' : this.petName,
        baseModelId: BREED_OPTIONS[this.breedIndex].id,
        photoUris: this.selectedUris,
      });
      this.palette = result.palette;
      this.statusText = `分析完成 (${result.sampledPhotos} 张照片, ${result.totalPixels} 像素)`;
      promptAction.showToast({ message: '宠物外观已更新, 返回主页查看' });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'build skin err: %{public}s', String(err));
      this.statusText = '生成失败: ' + String(err);
      promptAction.showToast({ message: '分析失败, 试试别的照片' });
    } finally {
      this.busy = false;
    }
  }

  private goBack(): void {
    try {
      router.back();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'router.back err: %{public}s', String(err));
    }
  }

  build() {
    Scroll() {
      Column() {
        Text('给我家宝贝拍写真')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 24, bottom: 6 });
        Text('选 1~5 张你家宠物的照片, 我们会提取主色, 给 3D 分身换装')
          .fontSize(13)
          .fontColor('#666')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 24 });

        this.sectionLabel('1. 给宝贝起个名字');
        TextInput({ placeholder: '我家宝贝', text: this.petName })
          .height(44)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .padding({ left: 16, right: 16 })
          .margin({ bottom: 16 })
          .onChange((v: string) => {
            this.petName = v;
          });

        this.sectionLabel('2. 选择品种 (套用对应 3D 模型)');
        Grid() {
          ForEach(BREED_OPTIONS, (opt: BreedOption, idx: number) => {
            GridItem() {
              this.breedChip(opt, idx);
            }
          }, (opt: BreedOption) => opt.id);
        }
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(8)
        .rowsGap(8)
        .height(140)
        .margin({ bottom: 16 });

        this.sectionLabel('3. 选照片');
        Button('选择宠物照片')
          .width('100%')
          .height(48)
          .backgroundColor('#FF8A5C')
          .fontColor('#FFFFFF')
          .borderRadius(14)
          .onClick(() => {
            this.pickPhotos();
          });

        if (this.selectedUris.length > 0) {
          this.thumbnailsRow();
        }

        this.sectionLabel('4. 生成宠物外观');
        Button(this.busy ? '分析中...' : '开始分析')
          .width('100%')
          .height(48)
          .backgroundColor(this.busy ? '#CCCCCC' : '#2A1F1A')
          .fontColor('#FFFFFF')
          .borderRadius(14)
          .enabled(!this.busy)
          .onClick(() => {
            this.generateSkin();
          });

        if (this.statusText.length > 0) {
          Text(this.statusText)
            .fontSize(12)
            .fontColor('#888')
            .margin({ top: 12 });
        }

        if (this.palette !== null) {
          this.paletteCard(this.palette);
        }

        Button('返回主页查看效果')
          .width('100%')
          .height(44)
          .backgroundColor('#FFFFFF')
          .fontColor('#FF8A5C')
          .borderColor('#FF8A5C')
          .borderWidth(1)
          .borderRadius(14)
          .margin({ top: 24, bottom: 24 })
          .onClick(() => {
            this.goBack();
          });
      }
      .padding({ left: 20, right: 20 })
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF8F0');
  }

  @Builder
  sectionLabel(text: string) {
    Row() {
      Text(text)
        .fontSize(13)
        .fontColor('#2A1F1A')
        .fontWeight(FontWeight.Medium);
    }
    .width('100%')
    .margin({ top: 8, bottom: 8 });
  }

  @Builder
  breedChip(opt: BreedOption, idx: number) {
    Text(opt.label)
      .fontSize(13)
      .fontColor(this.breedIndex === idx ? '#FFFFFF' : '#2A1F1A')
      .backgroundColor(this.breedIndex === idx ? '#FF8A5C' : '#FFFFFF')
      .borderRadius(12)
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .textAlign(TextAlign.Center)
      .width('100%')
      .onClick(() => {
        this.breedIndex = idx;
      });
  }

  @Builder
  thumbnailsRow() {
    Row() {
      ForEach(this.selectedUris, (uri: string) => {
        Image(uri)
          .width(72)
          .height(72)
          .borderRadius(10)
          .margin({ right: 8 })
          .objectFit(ImageFit.Cover);
      }, (uri: string) => uri);
    }
    .width('100%')
    .margin({ top: 12 });
  }

  @Builder
  paletteCard(p: ExtractResult) {
    Column() {
      Text('提取到的主色')
        .fontSize(13)
        .fontColor('#666')
        .margin({ bottom: 8 });
      Row() {
        this.swatch(p.primary, '主色');
        this.swatch(p.secondary, '副色');
        this.swatch(p.accent, '点缀');
      }
      .width('100%');
    }
    .padding(16)
    .margin({ top: 16 })
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .width('100%');
  }

  @Builder
  swatch(hex: string, label: string) {
    Column() {
      Circle({ width: 48, height: 48 })
        .fill(hex);
      Text(label)
        .fontSize(11)
        .fontColor('#666')
        .margin({ top: 6 });
      Text(hex)
        .fontSize(10)
        .fontColor('#999');
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center);
  }
}
