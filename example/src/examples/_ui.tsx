import type { ReactNode } from 'react';
import {
  Platform,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import type { StyleProp, TextStyle, ViewStyle } from 'react-native';

// ---- 设计令牌（与 App.tsx 外壳保持一致）----
export const DEMO = {
  primary: '#2563EB', // 主按钮 / 强调色
  primaryText: '#FFFFFF',
  danger: '#EF4444', // 危险操作（清除 / 删除）
  surface: 'rgba(255,255,255,0.95)', // 浮层卡片背景
  text: '#0F172A', // 主文字
  textMuted: '#475569', // 次要文字
  // 详情页底部有半透明的 Provider 切换栏，底部控件需上移这么多以免被遮挡
  bottomClearance: 100,
};

// 统一阴影：iOS 用 shadow*，Android/鸿蒙 用 elevation
export const DEMO_SHADOW = Platform.select({
  ios: {
    shadowColor: '#1E293B',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.14,
    shadowRadius: 8,
  },
  android: { elevation: 3 },
  default: {},
}) as ViewStyle;

type ButtonVariant = 'primary' | 'secondary' | 'danger';

// 统一按钮：primary 蓝底白字，secondary 白底蓝字，danger 白底红字
export function DemoButton({
  label,
  onPress,
  variant = 'primary',
  disabled,
  style,
}: {
  label: string;
  onPress: () => void;
  variant?: ButtonVariant;
  disabled?: boolean;
  style?: StyleProp<ViewStyle>;
}) {
  const isPrimary = variant === 'primary';
  const textStyle: TextStyle =
    variant === 'primary'
      ? styles.btnTextPrimary
      : variant === 'danger'
        ? styles.btnTextDanger
        : styles.btnTextSecondary;
  return (
    <TouchableOpacity
      activeOpacity={0.8}
      onPress={onPress}
      disabled={disabled}
      style={[
        styles.btn,
        isPrimary ? styles.btnPrimary : styles.btnSurface,
        disabled && styles.btnDisabled,
        style,
      ]}
    >
      <Text style={textStyle}>{label}</Text>
    </TouchableOpacity>
  );
}

// 按钮行：横向排列、自动换行、居中
export function DemoButtonRow({
  children,
  style,
}: {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
}) {
  return <View style={[styles.buttonRow, style]}>{children}</View>;
}

// 底部控件容器：绝对定位、水平居中、上移避开 Provider 栏
export function DemoControls({
  children,
  style,
}: {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
}) {
  return <View style={[styles.controls, style]}>{children}</View>;
}

// 提示气泡：浮层小卡片，承载说明文字或状态信息（可传字符串或自定义节点）
export function DemoHint({
  children,
  style,
}: {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
}) {
  return (
    <View style={[styles.hint, style]}>
      {typeof children === 'string' ? (
        <Text style={styles.hintText}>{children}</Text>
      ) : (
        children
      )}
    </View>
  );
}

// 信息面板：白色圆角卡片，用于键值读数 / 事件日志等
export function DemoPanel({
  children,
  style,
}: {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
}) {
  return <View style={[styles.panel, style]}>{children}</View>;
}

const styles = StyleSheet.create({
  controls: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: DEMO.bottomClearance,
    alignItems: 'center',
    gap: 12,
  },
  buttonRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: 12,
  },
  btn: {
    paddingHorizontal: 20,
    paddingVertical: 11,
    borderRadius: 22,
    ...DEMO_SHADOW,
  },
  btnPrimary: {
    backgroundColor: DEMO.primary,
  },
  btnSurface: {
    backgroundColor: DEMO.surface,
  },
  btnDisabled: {
    opacity: 0.5,
  },
  btnTextPrimary: {
    color: DEMO.primaryText,
    fontSize: 15,
    fontWeight: '600',
  },
  btnTextSecondary: {
    color: DEMO.primary,
    fontSize: 15,
    fontWeight: '600',
  },
  btnTextDanger: {
    color: DEMO.danger,
    fontSize: 15,
    fontWeight: '600',
  },
  hint: {
    maxWidth: '90%',
    backgroundColor: DEMO.surface,
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
    ...DEMO_SHADOW,
  },
  hintText: {
    fontSize: 13,
    color: DEMO.textMuted,
    textAlign: 'center',
  },
  panel: {
    backgroundColor: DEMO.surface,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 14,
    ...DEMO_SHADOW,
  },
});
