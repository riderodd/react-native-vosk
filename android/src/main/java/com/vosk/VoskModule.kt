package com.reactnativevosk

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.modules.core.DeviceEventManagerModule
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import org.vosk.android.StorageService
import java.io.IOException

class VoskModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext), RecognitionListener {
  private var model: Model? = null
  private var speechService: SpeechService? = null
  private var context: ReactApplicationContext? = reactContext
  private var recognizer: Recognizer? = null
  private var sampleRate = 16000.0f

  override fun getName(): String {
    return NAME
  }

  override fun onResult(hypothesis: String) {
    // Get text data from string object
    val text = parseHypothesis(hypothesis)

    // Send event if data found
    if (!text.isNullOrEmpty()) {
      sendEvent("onResult", text)
    }
  }

  override fun onFinalResult(hypothesis: String) {
    // Get text data from string object
    val text = parseHypothesis(hypothesis)

    // Send event if data found
    if (!text.isNullOrEmpty()) {
      sendEvent("onFinalResult", text)
    }
  }

  override fun onPartialResult(hypothesis: String) {
    // Get text data from string object
    val text = parseHypothesis(hypothesis, "partial")

    // Send event if data found
    if (!text.isNullOrEmpty()) {
      sendEvent("onPartialResult", text)
    }
  }

  override fun onError(e: Exception) {
    sendEvent("onError", e.toString())
  }

  override fun onTimeout() {
    sendEvent("onTimeout")
  }

  /**
   * Converts hypothesis json text to the recognized text
   * @return the recognized text or null if something went wrong
   */
  private fun parseHypothesis(hypothesis: String, key: String = "text"): String? {
    // Hypothesis is in the form: '{[key]: "recognized text"}'
    return try {
      val res = JSONObject(hypothesis)
      res.getString(key)
    } catch (tx: Throwable) {
      null
    }
  }

  /**
   * Sends event to react native with associated data
   */
  private fun sendEvent(eventName: String, data: String? = null) {
    // Write event data if there is some
    val event = Arguments.createMap().apply {
      if (data != null) putString("data", data)
    }

    // Send event
    context?.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)?.emit(
      eventName,
      event
    )
  }

  /**
   * Translates array of string(s) to required kaldi string format
   * @return the array of string(s) as a single string
   */
  private fun makeGrammar(grammarArray: ReadableArray): String {
    return grammarArray.toArrayList().joinToString(
      prefix = "[",
      separator = ", ",
      transform = {"\"" + it + "\""},
      postfix = "]"
    )
  }

  @ReactMethod
  fun loadModel(path: String, promise: Promise) {
    cleanModel()
    StorageService.unpack(context, path, "models",
      { model: Model? ->
        this.model = model
        promise.resolve("Model successfully loaded")
      }
    ) { e: IOException ->
      this.model = null
      promise.reject(e)
    }
  }

  @ReactMethod
  fun start(grammar: ReadableArray? = null, promise: Promise) {
    if (model == null) {
      promise.reject(IOException("Model is not loaded yet"))
    }
    else if (speechService != null) {
      promise.reject(IOException("Recognizer is already in use"))
    } else {
      try {
        recognizer =
          if (grammar != null)
            Recognizer(model, sampleRate, makeGrammar(grammar))
          else
            Recognizer(model, sampleRate)

        speechService = SpeechService(recognizer, sampleRate)

        return if (speechService!!.startListening(this))
          promise.resolve("Recognizer successfully started")
        else
          promise.reject(IOException("Recognizer couldn't be started"))

      } catch (e: IOException) {
        cleanModel()
        promise.reject(e)
      }
    }
  }

  @ReactMethod
  fun setGrammar(grammar: ReadableArray? = null, promise: Promise) {
    if (recognizer == null || speechService == null) {
      promise.reject(IOException("Recognizer is not started yet"))
    } else {
      try {
        speechService!!.stop()

        if (grammar != null)
          recognizer!!.setGrammar(makeGrammar(grammar))
        else
          recognizer!!.setGrammar("[]")

        speechService = SpeechService(recognizer, sampleRate)
        if (speechService!!.startListening(this))
          return promise.resolve("Recognizer successfully started")

      } catch (e: IOException) {
        promise.reject(e)
      }
    }
  }

  private fun cleanRecognizer() {
    if (speechService != null) {
      speechService!!.stop()
      speechService!!.shutdown()
      speechService = null
    }
    if (recognizer != null) {
      recognizer!!.close()
      recognizer = null
    }
  }

  private fun cleanModel() {
    if (this.model != null) {
      this.model!!.close()
      this.model = null
    }
  }

  @ReactMethod
  fun stop() {
    cleanRecognizer()
  }

  @ReactMethod
  fun unload() {
    cleanRecognizer()
    cleanModel()
  }

  companion object {
    const val NAME = "Vosk"
  }
}
