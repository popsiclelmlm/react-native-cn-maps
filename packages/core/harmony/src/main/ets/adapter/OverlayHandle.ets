/*
 * Opaque token returned by the adapter when a marker/overlay is added, and handed
 * back for later update/remove. The host keeps it on the child; only the adapter
 * that created it knows what `sdkObject` concretely is, keeping the host
 * provider-agnostic.
 *
 * ArkTS port of core/android `adapter/OverlayHandle.kt`.
 */
export class OverlayHandle {
  readonly childId: string;
  // The concrete provider SDK object (an AMap Marker / Polyline / ...). Typed as
  // Object so core carries no provider type; the owning adapter casts it back.
  sdkObject: Object | null = null;

  constructor(childId: string) {
    this.childId = childId;
  }
}
