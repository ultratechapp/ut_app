package pl.net.ultratech.ut_abonent

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Parametry Wi-Fi do raportu testu łącza (sygnał, link speed, częstotliwość).
/// RSSI i link speed nie wymagają uprawnień lokalizacji; SSID i BSSID nie są odczytywane.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pl.net.ultratech/wifi").setMethodCallHandler { call, result ->
            if (call.method != "parametry") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                @Suppress("DEPRECATION")
                val info = wm.connectionInfo
                result.success(
                    mapOf(
                        "rssi" to info.rssi,
                        "linkSpeed" to info.linkSpeed,
                        "czestotliwosc" to info.frequency,
                    )
                )
            } catch (e: Exception) {
                result.error("wifi", e.message, null)
            }
        }
    }
}
