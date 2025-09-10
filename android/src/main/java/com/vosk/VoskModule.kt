package com.vosk

import android.util.Log
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.modules.core.DeviceEventManagerModule
import java.io.IOException
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import org.vosk.android.StorageService
import com.vosk.NativeVoskSpec

@ReactModule(name = VoskModule.NAME)
class VoskModule(reactContext: ReactApplicationContext) :
        NativeVoskSpec(reactContext), RecognitionListener {

  private var model: Model? = null
  private var speechService: SpeechService? = null
  private var context: ReactApplicationContext? = reactContext
  private var recognizer: Recognizer? = null
  private var sampleRate = 16000.0f
  private var isStopping = false

  override fun getName(): String {
    return NAME
  }

  override fun onResult(hypothesis: String) {
    // Get text data from string object
    val text = parseHypothesis(hypothesis)

    // Send event if data found
    if (!text.isNullOrEmpty()) {
      emitOnResult(text)
    }
  }

  override fun onFinalResult(hypothesis: String) {
    // Get text data from string object
    val text = parseHypothesis(hypothesis)

    // Send event if data found
    if (!text.isNullOrEmpty()) {
      emitOnFinalResult(text)
    }
  }

  override fun onPartialResult(hypothesis: String) {
    // Get text data from string object
    val text = parseHypothesis(hypothesis, "partial")

    // Send event if data found
    if (!text.isNullOrEmpty()) {
      emitOnPartialResult(text)
    }
  }

  override fun onError(e: Exception) {
    emitOnError(e.toString())
  }

  override fun onTimeout() {
    cleanRecognizer()
    emitOnTimeout()
  }

  /**
   * Converts hypothesis json text to the recognized text
   * @return the recognized text or null if something went wrong
   */
  private fun parseHypothesis(hypothesis: String, key: String = "text"): String? {
    // Hypothesis is in the form: '{[key]: "recognized text"}'
    try {
      val res = JSONObject(hypothesis)
      return res.getString(key)
    } catch (tx: Throwable) {
      return null
    }
  }

  /** Sends event to react native with associated data */
  private fun sendEvent(eventName: String, data: String? = null) {
    // Send event
    context?.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            ?.emit(eventName, data)
  }

  /**
   * Translates array of string(s) to required kaldi string format
   * @return the array of string(s) as a single string
   */
  private fun makeGrammar(grammarArray: ReadableArray): String {
    return grammarArray
            .toArrayList()
            .joinToString(
                    prefix = "[",
                    separator = ", ",
                    transform = { "\"" + it + "\"" },
                    postfix = "]"
            )
  }

  override fun loadModel(path: String, promise: Promise) {
    cleanModel()
    try {
      this.model = Model(path)
      promise.resolve("Model successfully loaded")
    } catch (e: IOException) {
      println("Model directory does not exist at path: " + path)

      // Load model from main app bundle
      StorageService.unpack(
              context,
              path,
              "models",
              { model: Model? ->
                this.model = model
                promise.resolve("Model successfully loaded")
              }
      ) { e: IOException ->
        this.model = null
        promise.reject(e)
      }
    }
  }

  override fun start(options: ReadableMap?, promise: Promise) {
    if (model == null) {
      promise.reject(IOException("Model is not loaded yet"))
      return
    }
    if (speechService != null) {
      promise.reject(IOException("Recognizer is already in use"))
      return
    }
    try {
      recognizer =
              if (options != null && options.hasKey("grammar") && !options.isNull("grammar")) {
                Recognizer(model, sampleRate, makeGrammar(options.getArray("grammar")!!))
              } else {
                Recognizer(model, sampleRate)
              }
      speechService = SpeechService(recognizer, sampleRate)
      val started =
              if (options != null && options.hasKey("timeout") && !options.isNull("timeout")) {
                speechService?.startListening(this, options.getInt("timeout")) ?: false
              } else {
                speechService!!.startListening(this)
              }
      if (started) {
        promise.resolve("Recognizer successfully started")
      } else {
        cleanRecognizer()
        promise.reject(IOException("Recognizer couldn't be started"))
      }
    } catch (e: IOException) {
      cleanRecognizer()
      promise.reject(e)
    }
  }

  private fun cleanRecognizer() {
    synchronized(this) {
      if (isStopping) {
        return
      }
      isStopping = true
      try {
        speechService?.let {
          it.stop()
          it.shutdown()
          speechService = null
        }
        recognizer?.let {
          it.close()
          recognizer = null
        }
      } catch (e: Exception) {
        Log.w(NAME, "Error during cleanup in cleanRecognizer", e)
      } finally {
        isStopping = false
      }
    }
  }

  private fun cleanModel() {
    synchronized(this) {
      try {
        model?.let {
          it.close()
          model = null
        }
      } catch (e: Exception) {
        Log.w(NAME, "Error during model cleanup", e)
      }
    }
  }

  override fun stop() {
    cleanRecognizer()
  }

  override fun unload() {
    cleanRecognizer()
    cleanModel()
  }

  override fun addListener(type: String?) {
    // Keep: Required for RN built in Event Emitter Calls.
  }

  override fun removeListeners(count: Double): Unit {
    // Keep: Required for RN built in Event Emitter Calls.
  }

  companion object {
    const val NAME = "Vosk"
  }
}
