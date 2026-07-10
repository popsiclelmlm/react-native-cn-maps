/*
 * UIAbility entry for the HarmonyOS example app. RNAbility (from the RNOH SDK) boots
 * the RNInstance and loads the page; we only point it at the entry page.
 *
 * 查证: RNAbility API for the pinned RNOH 0.72 line (getPagePath / getAbilityName
 * names vary by version).
 */
import { RNAbility } from '@rnoh/react-native-openharmony';

export default class EntryAbility extends RNAbility {
  getPagePath(): string {
    return 'pages/Index';
  }
}
