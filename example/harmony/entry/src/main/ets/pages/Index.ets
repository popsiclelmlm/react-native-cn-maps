/*
 * Entry page of the HarmonyOS example app. Hosts the RN surface and wires the
 * custom-component builder so `RNMapsMapView` renders the core CnMapHostComponent.
 *
 * 查证: RNApp / ComponentBuilderContext / RNOHCoreContext / jsBundleProvider shapes
 * for the pinned RNOH 0.72 line — these RNOH host APIs evolve between versions. The
 * appKey 'CnMapsExample' matches example/app.json (AppRegistry.registerComponent).
 */
import {
  RNApp, RNOHCoreContext, ComponentBuilderContext, MetroJSBundleProvider, ResourceJSBundleProvider
} from '@rnoh/react-native-openharmony';
import { CnMapHostComponent, RN_MAPS_MAP_VIEW_TYPE } from 'rn-cn-maps';
import { createRNPackages } from '../RNPackagesFactory';

@Builder
function buildCustomRNComponent(ctx: ComponentBuilderContext) {
  // Render the core map host for `RNMapsMapView`. Add more `if` branches for other
  // custom components as needed.
  if (ctx.componentName === RN_MAPS_MAP_VIEW_TYPE) {
    CnMapHostComponent({
      ctx: ctx.rnComponentContext,
      tag: ctx.tag,
    })
  }
}

const wrappedCustomRNComponentBuilder = wrapBuilder(buildCustomRNComponent);

@Entry
@Component
struct Index {
  @StorageLink('RNOHCoreContext') private rnohCoreContext: RNOHCoreContext | undefined = undefined;

  build() {
    Column() {
      if (this.rnohCoreContext !== undefined) {
        RNApp({
          rnInstanceConfig: {
            createRNPackages,
            arkTsComponentNames: [RN_MAPS_MAP_VIEW_TYPE],
          },
          initialProps: {} as Record<string, string>,
          appKey: 'CnMapsExample',
          wrappedCustomRNComponentBuilder: wrappedCustomRNComponentBuilder,
          // Dev: Metro (run `npm run start` in example/ with the harmony preset).
          // Release: a bundled bundle.harmony.js under rawfile (built with
          // `react-native bundle-harmony`). 查证 provider names/params.
          jsBundleProvider: new MetroJSBundleProvider(),
        })
      }
    }
    .height('100%')
    .width('100%')
  }
}
