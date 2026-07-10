/**
 * 纯 RN 冒烟页（stage 0/1：不接任何地图 SDK / 原生地图组件）。
 *
 * 作用：在 RNOH 原生地图组件（RNMapsMarker/Polyline 等）尚未在 ArkUI 侧注册时，
 * 单独验证「RN 0.72.5 + RNOH 渲染管线能在鸿蒙模拟器上画出像素」。
 * 用法：把 index.js 的 `import App from './App'` 临时改为 `import App from './App.smoke'`，
 * 重启 app 即可看到本页；地图链路打通后再切回 './App'。
 */
import React, { useState } from 'react';
import { SafeAreaView, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

export default function App() {
  const [count, setCount] = useState(0);
  return (
    <SafeAreaView style={styles.fill}>
      <ScrollView contentContainerStyle={styles.body}>
        <Text style={styles.title}>RNOH 冒烟 OK ✅</Text>
        <Text style={styles.sub}>react-native 0.72.5 · HarmonyOS · 模拟器</Text>

        <View style={styles.card}>
          <Text style={styles.cardText}>点击计数：{count}</Text>
          <TouchableOpacity style={styles.btn} onPress={() => setCount((c) => c + 1)}>
            <Text style={styles.btnText}>+1（验证 JS↔原生 事件回路）</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.row}>
          <View style={[styles.swatch, { backgroundColor: '#1f6feb' }]} />
          <View style={[styles.swatch, { backgroundColor: '#2da44e' }]} />
          <View style={[styles.swatch, { backgroundColor: '#cf222e' }]} />
          <View style={[styles.swatch, { backgroundColor: '#bf8700' }]} />
        </View>

        <Text style={styles.note}>
          看到本页即说明 RNOH 布局/文本/触摸/重渲染均可用。下一步：在原生侧注册
          RNMapsMapView/Marker/Polyline 后切回 App.tsx 出图。
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  fill: { flex: 1, backgroundColor: '#ffffff' },
  body: { padding: 20, gap: 16 },
  title: { fontSize: 26, fontWeight: '700', color: '#111' },
  sub: { fontSize: 14, color: '#666' },
  card: { padding: 16, borderRadius: 12, backgroundColor: '#f3f6fb', gap: 12 },
  cardText: { fontSize: 18, color: '#111' },
  btn: { backgroundColor: '#1f6feb', paddingVertical: 12, borderRadius: 10, alignItems: 'center' },
  btnText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  row: { flexDirection: 'row', gap: 12 },
  swatch: { width: 56, height: 56, borderRadius: 10 },
  note: { fontSize: 13, lineHeight: 20, color: '#444' },
});
