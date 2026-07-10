/*
 * RNOH custom Fabric component for `RNMapsMapView`. Thin ArkUI view that bridges the
 * RNOH descriptor / command / event APIs to CnMapHostController (which holds the
 * provider-agnostic logic ported from MapView.kt) and renders the current provider's
 * ArkUI map via the factory's WrappedBuilder.
 *
 * 查证: This file is the single concentration of RNOH-0.72-version-specific API.
 * Names below follow the documented RNOH custom-component pattern; confirm each
 * against `@rnoh/react-native-openharmony` `.d.ts` of the pinned 0.72.x SDK:
 *   - RNComponentContext / descriptorRegistry.getDescriptor / subscribeToDescriptorChanges
 *   - componentCommandReceiver.registerCommandCallback
 *   - rnInstance.emitComponentEvent
 *   - Descriptor.childrenTags + per-child .type / .props
 * Once `codegen-harmony` runs, the props/event/command types become generated.
 */
import { RNComponentContext, RNOHContext, Tag } from '@rnoh/react-native-openharmony';
import { CnMapHostController, ChildNode } from './CnMapHostController';
import { RNMapsMapViewDescriptor, RNMapsMapViewProps, RN_MAPS_MAP_VIEW_TYPE } from './RNMapsMapViewDescriptor';
import { PropBag } from './ChildModelBuilder';

@Component
export struct CnMapHostComponent {
  ctx!: RNComponentContext;
  tag: Tag = 0;

  // descriptor 只用于逻辑（读子节点 / 转发 props），不参与渲染，故用普通字段而非 @State——
  // 否则 RNOH 在滚动等场景频繁刷新 descriptor（对象引用每次都变）会触发 build() 重跑。
  private descriptor: RNMapsMapViewDescriptor | null = null;
  // 渲染用的 frame：只有这几个 @State 参与 build。仅当 frame 实际变化时才更新它们，
  // 于是滚动时（frame 不变）build 不重跑 → 内层地图 XComponent 不被重建 → 不再“滚动就重载”。
  @State private frameWidth: number | string = '100%';
  @State private frameHeight: number | string = '100%';
  @State private frameX: number = 0;
  @State private frameY: number = 0;
  private controller: CnMapHostController | null = null;
  private unsubscribe: (() => void) | null = null;
  private unregisterCommand: (() => void) | null = null;

  aboutToAppear(): void {
    const descriptor = this.ctx.descriptorRegistry.getDescriptor<RNMapsMapViewDescriptor>(this.tag);
    this.descriptor = descriptor;
    this.applyFrame(descriptor);

    // ctx.uiAbilityContext is the common.Context provider adapters need to create
    // their map + forward privacy. 查证 exact accessor name.
    this.controller = new CnMapHostController(
      this.ctx.uiAbilityContext,
      (eventName: string, payload: Object) => {
        this.ctx.rnInstance.emitComponentEvent(this.tag, eventName, payload);
      },
      (): ChildNode[] => this.readChildren()
    );

    // Select provider + apply first props.
    this.controller.applyProps(descriptor.props);

    this.unsubscribe = this.ctx.descriptorRegistry.subscribeToDescriptorChanges(
      this.tag,
      (newDescriptor) => {
        this.descriptor = newDescriptor as RNMapsMapViewDescriptor;
        this.applyFrame(this.descriptor);
        this.controller?.applyProps(this.descriptor.props);
      }
    );

    this.unregisterCommand = this.ctx.componentCommandReceiver.registerCommandCallback(
      this.tag,
      (command: string, args: Object[]) => {
        this.controller?.handleCommand(command, args);
      }
    );
  }

  aboutToDisappear(): void {
    this.unsubscribe?.();
    this.unregisterCommand?.();
    this.controller?.destroy();
  }

  // Walk the Fabric child tags and read each dumb child's component type + props.
  private readChildren(): ChildNode[] {
    const d = this.descriptor;
    if (d === null) {
      return [];
    }
    const out: ChildNode[] = [];
    d.childrenTags.forEach((childTag: Tag) => {
      const cd = this.ctx.descriptorRegistry.getDescriptor(childTag);
      if (cd !== undefined && cd !== null) {
        out.push({ tag: childTag, componentName: cd.type, props: cd.props as PropBag });
      }
    });
    return out;
  }

  // 把 Fabric 算好的 frame 同步到渲染用的 @State，但只在真正变化时才赋值：
  // 相等赋值会被跳过，从而避免滚动时（frame 不变、descriptor 却在刷新）无谓地重跑 build()。
  private applyFrame(d: RNMapsMapViewDescriptor | null): void {
    if (d === null) {
      return;
    }
    const f = d.layoutMetrics.frame;
    if (this.frameWidth !== f.size.width) {
      this.frameWidth = f.size.width;
    }
    if (this.frameHeight !== f.size.height) {
      this.frameHeight = f.size.height;
    }
    if (this.frameX !== f.origin.x) {
      this.frameX = f.origin.x;
    }
    if (this.frameY !== f.origin.y) {
      this.frameY = f.origin.y;
    }
  }

  build() {
    Stack() {
      // Render the current provider's ArkUI map. The factory's WrappedBuilder takes
      // the adapter so the provider can bind its map controller to it on map-ready.
      if (this.controller?.mapBuilder !== null && this.controller?.currentAdapter !== null) {
        this.controller!.mapBuilder!.builder(this.controller!.currentAdapter!);
      }
    }
    // RNOH 不给自定义 arkTS 组件套 RNViewBase，宿主要自己把 Fabric 算好的 frame（来自 JS
    // style 的宽高/位置）应用上去，否则内层地图会撑满父节点 → 全屏。用只在变化时更新的 @State
    // frame（见 applyFrame）而非直接读 descriptor，避免滚动时 build 重跑导致地图重建。
    .width(this.frameWidth)
    .height(this.frameHeight)
    .position({ x: this.frameX, y: this.frameY })
    .onAreaChange(() => {
      this.controller?.onSizeChanged();
    })
  }
}

// Component type string the app's custom-component builder switches on.
export const CN_MAP_HOST_COMPONENT_TYPE: string = RN_MAPS_MAP_VIEW_TYPE;
