package com.reactnativevosk

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.Promise

abstract class VoskSpec internal constructor(context: ReactApplicationContext) :
  ReactContextBaseJavaModule(context) {

  abstract fun loadModel(path: String, promise: Promise)
  abstract fun start(options: ReadableMap? = null, promise: Promise)
  abstract fun stop(promise: Promise)
  abstract fun unload(promise: Promise)
  abstract fun addListener(eventName: String)
  abstract fun removeListeners(count: Int)
}