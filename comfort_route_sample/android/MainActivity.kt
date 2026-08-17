package com.fx564286.comfort_route_sample

import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "comfort_route/navigation_tts"
    }

    private var textToSpeech: TextToSpeech? = null
    @Volatile private var ttsReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        textToSpeech = TextToSpeech(this) { status ->
            val engine = textToSpeech
            if (status == TextToSpeech.SUCCESS && engine != null) {
                val languageResult = engine.setLanguage(Locale.KOREAN)
                ttsReady = languageResult != TextToSpeech.LANG_MISSING_DATA &&
                    languageResult != TextToSpeech.LANG_NOT_SUPPORTED
                if (ttsReady) {
                    engine.setSpeechRate(1.0f)
                    engine.setPitch(1.0f)
                }
            } else {
                ttsReady = false
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(ttsReady)
                    "speak" -> {
                        val text = call.argument<String>("text")?.trim().orEmpty()
                        if (text.isEmpty()) {
                            result.error("EMPTY_TEXT", "안내 문구가 비어 있습니다.", null)
                        } else if (!ttsReady || textToSpeech == null) {
                            result.error("TTS_NOT_READY", "한국어 음성 엔진이 아직 준비되지 않았습니다.", null)
                        } else {
                            val code = textToSpeech!!.speak(
                                text,
                                TextToSpeech.QUEUE_FLUSH,
                                null,
                                "comfort-route-guidance"
                            )
                            if (code == TextToSpeech.ERROR) {
                                result.error("TTS_ERROR", "음성 재생을 시작하지 못했습니다.", null)
                            } else {
                                result.success(true)
                            }
                        }
                    }
                    "stop" -> {
                        textToSpeech?.stop()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        ttsReady = false
        super.onDestroy()
    }
}
