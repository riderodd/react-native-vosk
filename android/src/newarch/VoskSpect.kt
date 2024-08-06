package com.reactnativevosk

import com.facebook.react.bridge.ReactApplicationContext

abstract class VoskSpec internal constructor(context: ReactApplicationContext) :
  NativeVoskSpec(context) {
}