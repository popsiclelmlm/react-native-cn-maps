package com.cnmaps.adapter

import android.content.Context

// Registry of map provider factories. A provider package self-registers its
// factory (from its ReactPackage in M2; from MapsPackage in M1) and the host asks
// the registry for a map instead of naming a concrete SDK class — which is what
// lets core carry zero provider references.
object CnMapAdapterRegistry {
  private val factories = ArrayList<CnMapAdapterFactory>()

  @JvmStatic
  @Synchronized
  fun register(factory: CnMapAdapterFactory) {
    if (factories.none { it.javaClass == factory.javaClass }) {
      factories.add(factory)
    }
  }

  @JvmStatic
  @Synchronized
  fun hasAdapter(): Boolean = factories.isNotEmpty()

  // Create a map from the default (first-registered) factory, or null if none.
  @JvmStatic
  @Synchronized
  fun createAdapter(context: Context): CnMapAdapter? = factories.firstOrNull()?.create(context)

  // Fan a privacy-compliance declaration out to every registered factory.
  @JvmStatic
  @Synchronized
  fun applyPrivacyConsent(context: Context, agreed: Boolean, contains: Boolean, shown: Boolean) {
    factories.forEach { it.applyPrivacyConsent(context, agreed, contains, shown) }
  }
}
