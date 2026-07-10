/**
 * 让 strict-API typecheck 能解析这两个深路径导入。
 *
 * 背景：RNOH(HarmonyOS) 把裸 `react-native` 重定向到 `@react-native-oh/
 * react-native-harmony`，而该入口并未导出 `codegenNativeComponent` /
 * `codegenNativeCommands`，所以 `*NativeComponent.ts` 必须从深路径默认导入这两个
 * 函数（iOS/Android 的 RN 0.85 与 RNOH 的 RN 0.72 都带这两个文件，codegen 仅按本地
 * 名识别 → 三端通用）。
 *
 * 但本仓库 tsconfig 用 `moduleResolution: bundler` + `customConditions:
 * ["react-native-strict-api"]`，strict-API 的 exports 把 `./Libraries/*` 标为
 * null（屏蔽内部深路径），导致 tsc 报 TS2307。RN 内部的 Codegen 声明在 strict-API
 * 下不会被加载，故此处补一份对齐 RN 公开签名的 ambient 声明，不会与之冲突。
 */
declare module 'react-native/Libraries/Utilities/codegenNativeComponent' {
  import type { HostComponent } from 'react-native';

  interface Options {
    readonly interfaceOnly?: boolean | undefined;
    readonly paperComponentName?: string | undefined;
    readonly paperComponentNameDeprecated?: string | undefined;
    readonly excludedPlatforms?: ReadonlyArray<'iOS' | 'android'> | undefined;
    readonly generateOptionalProperties?: boolean | undefined;
    readonly generateOptionalObjectProperties?: boolean | undefined;
  }

  function codegenNativeComponent<Props extends object>(
    componentName: string,
    options?: Options
  ): HostComponent<Props>;

  export default codegenNativeComponent;
}

declare module 'react-native/Libraries/Utilities/codegenNativeCommands' {
  interface Options<T extends string> {
    readonly supportedCommands: ReadonlyArray<T>;
  }

  function codegenNativeCommands<T extends object>(
    options: Options<keyof T extends string ? keyof T : never>
  ): T;

  export default codegenNativeCommands;
}
