/*
 * Provider package for AMap on HarmonyOS (RNOH). Its entire job — like
 * amap/android `AMapPackage.kt` — is to register the AMap factory with the core
 * CnMapAdapterRegistry. It contributes no TurboModules/components; the host
 * component lives in core. The host app instantiates this in its RNPackagesFactory.
 *
 * 查证: RNPackage base + ctx signature for the pinned RNOH 0.72 line; the AMap ArkUI
 * map component name + onMapReady controller surfacing; MapsInitializer privacy API.
 */
import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import bundleManager from '@ohos.bundle.bundleManager';
import {
  RNPackage, TurboModulesFactory, TurboModule, TurboModuleContext, RNPackageContext
} from '@rnoh/react-native-openharmony/ts';
import {
  CnMapAdapter, CnMapAdapterFactory, CnMapBuilder, CnMapAdapterRegistry
} from 'rn-cn-maps';
import { AMapAdapter } from './AMapAdapter';
// 真实高德鸿蒙 SDK：地图组件 + 控制器 + 初始化（map3d）；隐私状态枚举（common）。
import {
  MapsInitializer, MapView, MapViewComponent, MapViewManager, MapViewCreateCallback, AMap
} from '@amap/amap_lbs_map3d';
import {
  AMapPrivacyShowStatus, AMapPrivacyInfoStatus, AMapPrivacyAgreeStatus
} from '@amap/amap_lbs_common';

// 高德 Key 存放在宿主 example 的 module.json5 metadata（与 Android manifest meta-data 同名）。
const AMAP_KEY_METADATA = 'com.amap.api.v2.apikey';
// 隐私合规 + setApiKey 全局只做一次；成功后置 true，避免多个地图实例重复初始化。
let amapInitialized = false;

// 从宿主应用 module.json5 的 metadata 读取高德 Key（复用百度端已真机验证的读法）。
function readAmapKey(): string {
  try {
    // metadata 挂在 hapModulesInfo 下，必须同时带 WITH_HAP_MODULE，否则 hapModulesInfo 为空。
    const info = bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_HAP_MODULE |
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_METADATA);
    const modules = info.hapModulesInfo;
    for (let i = 0; i < modules.length; i++) {
      const metas = modules[i].metadata;
      for (let j = 0; j < metas.length; j++) {
        if (metas[j].name === AMAP_KEY_METADATA) {
          return metas[j].value;
        }
      }
    }
  } catch (e) {
    hilog.error(0x0000, 'cnmaps', 'read amap key failed: %{public}s', JSON.stringify(e));
  }
  return '';
}

// 高德 SDK 初始化：隐私三步（updatePrivacyShow/Agree）+ setApiKey，必须在任何地图接口前。
// 幂等：全局只成功执行一次。context 用宿主 UIAbility context。
function ensureAmapInitialized(context: common.Context, agreed: boolean, contains: boolean, shown: boolean): void {
  if (amapInitialized) {
    return;
  }
  try {
    MapsInitializer.updatePrivacyShow(
      shown ? AMapPrivacyShowStatus.DidShow : AMapPrivacyShowStatus.NotShow,
      contains ? AMapPrivacyInfoStatus.DidContain : AMapPrivacyInfoStatus.NotContain,
      context);
    MapsInitializer.updatePrivacyAgree(
      agreed ? AMapPrivacyAgreeStatus.DidAgree : AMapPrivacyAgreeStatus.NotAgree,
      context);
    if (!agreed) {
      return;
    }
    const key = readAmapKey();
    if (key.length === 0) {
      hilog.warn(0x0000, 'cnmaps', 'amap key missing: 请在 module.json5 metadata 配置 com.amap.api.v2.apikey');
      return;
    }
    MapsInitializer.setApiKey(key);
    amapInitialized = true;
    hilog.info(0x0000, 'cnmaps', 'amap SDK initialized (privacy agreed + apiKey set)');
  } catch (e) {
    hilog.error(0x0000, 'cnmaps', 'amap SDK init error: %{public}s', JSON.stringify(e));
  }
}

/*
 * 高德鸿蒙地图的 ArkUI 宿主组件。与百度不同：百度 MapComponent 自带 onReady 回调，无状态
 * @Builder 即可；高德 MapViewComponent 不带回调，控制器要经全局 MapViewManager 注册回调 +
 * 按 mapViewName 命名匹配拿到 MapView，再 getMapAsync 得到 AMap 控制器。这些都需要生命周期
 * 钩子，故用 @Component struct（而非无状态 @Builder）。底图由 MapViewComponent 自渲染，不
 * 依赖控制器绑定。
 */
@Component
struct AMapHostView {
  // 由 builder 传入的同一个 adapter 实例（保持引用，不可用 @Prop 深拷贝）。
  adapter!: AMapAdapter;
  private mapView: MapView | null = null;

  // MapViewManager 会对所有 MapView 广播；只认领 mapViewName 等于本 adapter 的那个，且只绑一次。
  private onMapViewCreated: MapViewCreateCallback = (mapView?: MapView, name?: string) => {
    if (!mapView || this.mapView !== null || name !== this.adapter.mapViewName) {
      return;
    }
    this.mapView = mapView;
    this.mapView.onCreate();
    this.mapView.getMapAsync((map: AMap) => {
      // 底图已由组件渲染；attachController 里监听器/覆盖物尚未全对齐真实 API，兜住不阻断。
      try {
        this.adapter.attachController(map);
      } catch (e) {
        hilog.warn(0x0000, 'cnmaps', 'amap attachController error (map still renders): %{public}s', JSON.stringify(e));
      }
    });
  };

  aboutToAppear(): void {
    // 兜底初始化：即使 JS 侧未主动调隐私授权，地图挂载时也确保 SDK 已初始化（默认同意）。
    ensureAmapInitialized(getContext(this) as common.Context, true, true, true);
    MapViewManager.getInstance().registerMapViewCreatedCallback(this.onMapViewCreated);
  }

  aboutToDisappear(): void {
    MapViewManager.getInstance().unregisterMapViewCreatedCallback(this.onMapViewCreated);
    if (this.mapView !== null) {
      this.mapView.onDestroy();
      this.mapView = null;
    }
  }

  build() {
    MapViewComponent({ mapViewName: this.adapter.mapViewName })
      .width('100%')
      .height('100%')
  }
}

// ArkUI builder：渲染真实高德地图宿主组件（AMapHostView），控制器经 MapViewManager 异步交付。
@Builder
function amapMapBuilder(adapter: CnMapAdapter) {
  AMapHostView({ adapter: adapter as AMapAdapter })
}

class AMapFactory implements CnMapAdapterFactory {
  readonly providerName: string = 'amap';

  create(context: common.Context): CnMapAdapter {
    return new AMapAdapter(context);
  }

  mapBuilder(): CnMapBuilder {
    return wrapBuilder(amapMapBuilder);
  }

  applyPrivacyConsent(context: common.Context, agreed: boolean, contains: boolean, shown: boolean): void {
    // 由 JS 侧 setPrivacyConsent 触发（经 CnMapAdapterRegistry 分发到各 provider）。高德要求
    // 隐私合规 + setApiKey 在任何地图接口前完成；AMapHostView.aboutToAppear 亦会兜底调用。
    ensureAmapInitialized(context, agreed, contains, shown);
  }
}

export const AMapAdapterFactory: CnMapAdapterFactory = new AMapFactory();

// No TurboModules from this package (parity with Android's empty AMapPackage).
class EmptyTurboModulesFactory extends TurboModulesFactory {
  createTurboModule(_name: string): TurboModule | null {
    return null;
  }
  hasTurboModule(_name: string): boolean {
    return false;
  }
}

export class AMapPackage extends RNPackage {
  constructor(ctx: RNPackageContext) {
    super(ctx);
    // Self-register the AMap factory — this is the package's whole purpose.
    CnMapAdapterRegistry.register(AMapAdapterFactory);
  }

  createTurboModulesFactory(ctx: TurboModuleContext): TurboModulesFactory {
    return new EmptyTurboModulesFactory(ctx);
  }
}
