package com.cnmaps

import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Shared off-UI image decoding for marker / overlay icons.
 *
 * Replaces the per-call `Thread { URL(uri).openStream() }` pattern (which had no
 * connect/read timeout — a stalled network would pin the thread forever — and
 * spawned an unbounded number of threads) with a single shared daemon pool and
 * explicit timeouts. (F2)
 */
internal object MapsImageLoader {
  private const val CONNECT_TIMEOUT_MS = 15_000
  private const val READ_TIMEOUT_MS = 15_000

  /** Shared daemon pool so repeated icon loads don't churn one Thread per image. */
  val executor: ExecutorService =
    Executors.newCachedThreadPool { runnable ->
      Thread(runnable, "cn-maps-image").apply { isDaemon = true }
    }

  /**
   * Decode a marker/overlay image uri off the UI thread. Supports http(s) (with
   * timeouts), `file://`, and a drawable resource name. Returns null on failure.
   * Must be called from a background thread (e.g. [executor]).
   */
  fun decode(uri: String, resources: Resources, packageName: String): Bitmap? =
    runCatching {
      when {
        uri.startsWith("http://") || uri.startsWith("https://") -> decodeHttp(uri)
        uri.startsWith("file://") -> BitmapFactory.decodeFile(Uri.parse(uri).path)
        else -> {
          val resId = resources.getIdentifier(uri, "drawable", packageName)
          if (resId != 0) BitmapFactory.decodeResource(resources, resId) else null
        }
      }
    }.getOrNull()

  private fun decodeHttp(uri: String): Bitmap? {
    val connection = (URL(uri).openConnection() as HttpURLConnection).apply {
      connectTimeout = CONNECT_TIMEOUT_MS
      readTimeout = READ_TIMEOUT_MS
      instanceFollowRedirects = true
    }
    return try {
      connection.inputStream.use { BitmapFactory.decodeStream(it) }
    } finally {
      connection.disconnect()
    }
  }
}
