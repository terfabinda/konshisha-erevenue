package com.konshisha.app.konshisha_igr

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.os.Build
import android.util.Log
import java.util.UUID

data class BluetoothDeviceInfo(
    val name: String,
    val address: String,
    val rssi: Int,
    val isPrinter: Boolean = false,
)

class BleScanner(private val context: Context) {
    companion object {
        private const val TAG = "BleScanner"
        
        // Common Bluetooth printer service UUIDs
        private val PRINTER_UUIDS = setOf(
            "180A",  // Device Information Service
            "18F0",  // Android Device Information Service
            "1812",  // Human Interface Device Service (some printers use this)
            "00001101-0000-1000-8000-00805F9B34FB", // Serial Port Profile (SPP)
            "00001105-0000-1000-8000-00805F9B34FB", // Object Push Profile
        )
        
        // Keywords that indicate a printer device - comprehensive list
        private val PRINTER_KEYWORDS = listOf(
            // Generic printer terms
            "printer", "thermal", "receipt", "pos", "print", "mdram",
            
            // International brands
            "xprinter", "gprinter", "zebra", "epson", "brother", "star",
            "woosim", "sewoo", "brecknell", "intermec", "ikonics", 
            "datamax", "eltron", "tsc", "avery", "sato",
            
            // Chinese brands and common Chinese POS devices
            "sunmi", "happybaby", "goodbaby", "imin", "wishepos", 
            "urovo", "pax", "newland", "jingchen", "gainscha", "raytone",
            "winpos", "loyverse", "bp200", "bp210", "bp220", "bpa100",
            
            // Common Chinese characters/romanizations
            "蓝牙", "打印", "收据", "小票", // Chinese characters
            "lanxue", "dayin", "xiaopiao", // Romanized Chinese
            "chinapos", "pos terminal", "mobility",
            
            // Generic patterns that indicate printing capability
            "bluetooth_printer", "btprinter", "ble_printer",
            "printing", "line printer", "dot matrix",
            
            // Mobile/Portable printers (common in POS)
            "portable", "mobile", "portable print", "mpos"
        )
    }
    
    private val bluetoothManager: BluetoothManager? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?
        } else {
            null
        }

    private val bluetoothAdapter: BluetoothAdapter? =
        bluetoothManager?.adapter ?: BluetoothAdapter.getDefaultAdapter()

    private val bleScanner: BluetoothLeScanner? = bluetoothAdapter?.bluetoothLeScanner
    private val discoveredDevices = mutableMapOf<String, BluetoothDeviceInfo>()
    private var isScanning = false

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            super.onScanResult(callbackType, result)
            result?.let {
                val device = it.device
                val address = device.address
                val name = device.name ?: "Unknown Device"
                val rssi = it.rssi
                
                // Check if this is likely a printer device
                val isPrinter = isPrinterDevice(name, it)
                
                // Only store devices that look like printers or have potential service info
                if (isPrinter || (name.isNotEmpty() && !name.equals("Unknown Device"))) {
                    // If it's identified as a printer, prioritize it; otherwise still store with lower priority
                    discoveredDevices[address] = BluetoothDeviceInfo(
                        name = name,
                        address = address,
                        rssi = rssi,
                        isPrinter = isPrinter,
                    )
                    
                    if (isPrinter) {
                        Log.d(TAG, "Found printer device: $name ($address) RSSI: $rssi")
                    }
                }
            }
        }

        override fun onScanFailed(errorCode: Int) {
            super.onScanFailed(errorCode)
            Log.e(TAG, "Scan failed with error code: $errorCode")
            isScanning = false
        }
    }
    
    /**
     * Detect if a device is likely a Bluetooth printer
     * Uses multiple signals: device name keywords, MAC address prefix, and advertised services
     */
    private fun isPrinterDevice(name: String, result: ScanResult): Boolean {
        val device = result.device
        val address = device.address
        val nameLower = name.lowercase()
        
        // 1. Check device name against printer keywords (highest confidence)
        for (keyword in PRINTER_KEYWORDS) {
            if (nameLower.contains(keyword)) {
                Log.d(TAG, "Printer detected by name keyword '$keyword': $name ($address)")
                return true
            }
        }
        
        // 2. Check manufacturer MAC address prefixes (known printer manufacturers)
        val macPrefix = address.substring(0, 8).uppercase()
        val knownPrinterMacPrefixes = mapOf(
            "7805D3" to "Xprinter",      // Xprinter manufacturer
            "00124B" to "Star Micronics",
            "000C65" to "Zebra",
            "0050F2" to "Microsoft (Surface/devices)",
            "080007" to "GPRINTER",
            "3C3728" to "Thermal Printer (Generic)",
            "D0A5C6" to "POS Terminal",
            "702AB7" to "Mobile/Portable Printer"
        )
        
        if (macPrefix in knownPrinterMacPrefixes) {
            Log.d(TAG, "Printer detected by MAC prefix ($macPrefix - ${knownPrinterMacPrefixes[macPrefix]}): $name ($address)")
            return true
        }
        
        // 3. Check advertised services (if available)
        val scanRecord = result.scanRecord
        if (scanRecord != null) {
            val serviceUuids = scanRecord.serviceUuids
            if (serviceUuids != null) {
                for (uuid in serviceUuids) {
                    val uuidString = uuid.toString().uppercase()
                    // Check if any advertised service matches printer UUIDs
                    for (printerUuid in PRINTER_UUIDS) {
                        if (uuidString.contains(printerUuid)) {
                            Log.d(TAG, "Printer detected by service UUID ($printerUuid): $name ($address)")
                            return true
                        }
                    }
                }
            }
        }
        
        // 4. Fallback: If name contains common printer patterns but no other match
        // This catches edge cases like generic "Bluetooth Printer" names
        if (nameLower.contains("bluetooth") && 
            (nameLower.contains("printer") || nameLower.contains("print") || 
             nameLower.contains("thermal") || nameLower.contains("receipt"))) {
            Log.d(TAG, "Printer detected by name pattern: $name ($address)")
            return true
        }
        
        // Log non-printer devices for debugging
        if (name.isNotEmpty() && !name.equals("Unknown Device", ignoreCase = true)) {
            Log.d(TAG, "Non-printer device detected: $name ($address)")
        }
        
        return false
    }

    fun startScan(): Boolean {
        if (isScanning || bleScanner == null) {
            return false
        }

        discoveredDevices.clear()
        isScanning = true
        Log.d(TAG, "Starting BLE scan for printer devices")
        bleScanner.startScan(scanCallback)
        return true
    }

    fun stopScan(): Boolean {
        if (!isScanning || bleScanner == null) {
            return false
        }

        bleScanner.stopScan(scanCallback)
        isScanning = false
        Log.d(TAG, "Stopped BLE scan. Found ${discoveredDevices.size} devices")
        return true
    }

    /**
     * Get discovered devices, sorted by:
     * 1. Confirmed printer devices first
     * 2. By signal strength (RSSI) - higher is better (less negative)
     */
    fun getDiscoveredDevices(): List<BluetoothDeviceInfo> {
        return discoveredDevices.values
            .sortedWith(
                compareBy<BluetoothDeviceInfo> { !it.isPrinter }  // Printers first
                    .thenBy { -it.rssi }  // Then by strongest signal
            )
    }

    fun isBluetoothSupported(): Boolean {
        return bluetoothAdapter != null
    }

    fun isBluetoothEnabled(): Boolean {
        return bluetoothAdapter?.isEnabled ?: false
    }
}
