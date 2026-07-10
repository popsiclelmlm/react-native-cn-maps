/**
 * Codegen 标量/事件类型，以「裸名」提供（WithDefault / Double / Int32 / Float /
 * BubblingEventHandler / DirectEventHandler）。
 *
 * 为什么需要：RNOH（HarmonyOS）走 RN 0.72 线，其 codegen 解析器按裸标识符名识别这些
 * 类型（`type.typeName.name === 'WithDefault'`，在 types-map 解析之前优先匹配），
 * 不认 `CodegenTypes.WithDefault` 这种限定名（命名空间写法是 0.74+ 才加的）——遇到它会
 * 报 `Unknown prop type ... undefined`，导致整个库的 codegen 失败、组件拿不到 RNOH 的
 * ComponentJSIBinder，JS 端 `requireNativeComponent` 全部 "not found in the UIManager"。
 *
 * 这里给出的别名解析后的类型与 RN 公开的 `CodegenTypes.*` 完全一致（WithDefault → 值|null|
 * undefined；Double/Int32/Float → number；事件 → (e: NativeSyntheticEvent<T>) => …），所以
 * 对 iOS/Android（RN 0.85）既不改变类型语义、又同样被其 codegen 按名识别 → 三端通用。
 */
import type { NativeSyntheticEvent } from 'react-native';

export type Double = number;
export type Float = number;
export type Int32 = number;

// WithDefault<Type, Value>: 运行时类型是 Type（含可空）；第二个参数 Value 仅供 codegen
// 读取默认值（spec 写 `WithDefault<boolean, false>`，codegen 要求恰好两个参数）。
// `Value & never` 恒为 never（不改变解析后的类型），仅用于「引用」Value 以满足 noUnused。
export type WithDefault<Type, Value = Type | string> =
  | Type
  | null
  | undefined
  | (Value & never);

export type BubblingEventHandler<T> = (
  event: NativeSyntheticEvent<T>
) => void | Promise<void>;

export type DirectEventHandler<T> = (
  event: NativeSyntheticEvent<T>
) => void | Promise<void>;
