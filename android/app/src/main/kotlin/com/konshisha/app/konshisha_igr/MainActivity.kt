package com.konshisha.app.konshisha_igr

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.konshisha.app.konshisha_igr/ble_scanner"
    private lateinit var bleScanner: BleScanner

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        bleScanner = BleScanner(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScan" -> {
                    try {
                        val success = bleScanner.startScan()
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("SCAN_ERROR", e.message, null)
                    }
                }

                "stopScan" -> {
                    try {
                        val success = bleScanner.stopScan()
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("SCAN_ERROR", e.message, null)
                    }
                }

                "getDiscoveredDevices" -> {
                    try {
                        val devices = bleScanner.getDiscoveredDevices()
                        val deviceList = devices.map { device ->
                            mapOf(
                                "name" to device.name,
                                "address" to device.address,
                                "rssi" to device.rssi,
                                "isPrinter" to device.isPrinter,
                            )
                        }
                        result.success(deviceList)
                    } catch (e: Exception) {
                        result.error("SCAN_ERROR", e.message, null)
                    }
                }

                "isBluetoothSupported" -> {
                    try {
                        val supported = bleScanner.isBluetoothSupported()
                        result.success(supported)
                    } catch (e: Exception) {
                        result.error("CHECK_ERROR", e.message, null)
                    }
                }

                "isBluetoothEnabled" -> {
                    try {
                        val enabled = bleScanner.isBluetoothEnabled()
                        result.success(enabled)
                    } catch (e: Exception) {
                        result.error("CHECK_ERROR", e.message, null)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
