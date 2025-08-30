package dev.magtek.card_reader

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.util.Log
import kotlinx.coroutines.*
import java.util.*
import kotlin.collections.HashMap

data class DeviceInfo(
    val deviceId: String,
    val deviceName: String,
    val vendorId: Int,
    val productId: Int,
    val serialNumber: String?,
    val devicePath: String,
    val isConnected: Boolean
)

data class CardData(
    val track1: String?,
    val track2: String?,
    val track3: String?,
    val deviceId: String,
    val rawResponse: String,
    val timestamp: Long
)

class AndroidUsbDeviceManager(private val context: Context) {
    companion object {
        private const val TAG = "MagtekUSBManager"
        private const val ACTION_USB_PERMISSION = "com.example.magtek_card_reader.USB_PERMISSION"
        private const val MAGTEK_VENDOR_ID = 0x0801
        private val MAGTEK_PRODUCT_IDS = intArrayOf(
            0x0001, // Magtek Mini Swipe Reader
            0x0002, // Magtek USB Swipe Reader
            0x0003, // Magtek eDynamo
            0x0004, // Magtek uDynamo
            0x0010  // Magtek SureSwipe Reader
        )
    }

    private val usbManager: UsbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private var currentDevice: UsbDevice? = null
    private var currentConnection: UsbDeviceConnection? = null
    private var currentInterface: UsbInterface? = null
    private var currentEndpoint: UsbEndpoint? = null
    private var currentDeviceId: String? = null

    private val monitoringScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var isMonitoring = false

    var cardSwipeCallback: ((CardData) -> Unit)? = null
    var deviceConnectionCallback: ((DeviceInfo) -> Unit)? = null

    private val usbPermissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (ACTION_USB_PERMISSION == intent.action) {
                synchronized(this) {
                    val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                        device?.let {
                            Log.d(TAG, "USB permission granted for device: ${it.deviceName}")
                            connectToDeviceInternal(it)
                        }
                    } else {
                        Log.d(TAG, "USB permission denied for device: ${device?.deviceName}")
                    }
                }
            }
        }
    }

    private val usbDetachReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (UsbManager.ACTION_USB_DEVICE_DETACHED == intent.action) {
                val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                device?.let {
                    if (isMagtekDevice(it.vendorId, it.productId)) {
                        Log.d(TAG, "Magtek device detached: ${it.deviceName}")
                        if (currentDevice?.deviceId == it.deviceId) {
                            disconnect()
                        }
                    }
                }
            }
        }
    }

    fun initialize(): Boolean {
        return try {
            // Register USB permission receiver
            val permissionFilter = IntentFilter(ACTION_USB_PERMISSION)
            context.registerReceiver(usbPermissionReceiver, permissionFilter)

            // Register USB detach receiver
            val detachFilter = IntentFilter(UsbManager.ACTION_USB_DEVICE_DETACHED)
            context.registerReceiver(usbDetachReceiver, detachFilter)

            Log.d(TAG, "USB device manager initialized")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize USB device manager", e)
            false
        }
    }

    fun cleanup() {
        try {
            stopMonitoring()
            disconnect()
            context.unregisterReceiver(usbPermissionReceiver)
            context.unregisterReceiver(usbDetachReceiver)
            monitoringScope.cancel()
            Log.d(TAG, "USB device manager cleaned up")
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
    }

    fun getConnectedDevices(): List<DeviceInfo> {
        val devices = mutableListOf<DeviceInfo>()
        
        try {
            val deviceMap = usbManager.deviceList
            for (device in deviceMap.values) {
                if (isMagtekDevice(device.vendorId, device.productId)) {
                    val deviceInfo = DeviceInfo(
                        deviceId = device.deviceId.toString(),
                        deviceName = getDeviceName(device.vendorId, device.productId),
                        vendorId = device.vendorId,
                        productId = device.productId,
                        serialNumber = device.serialNumber,
                        devicePath = device.deviceName,
                        isConnected = currentDevice?.deviceId == device.deviceId
                    )
                    devices.add(deviceInfo)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting connected devices", e)
        }
        
        return devices
    }

    fun connectToDevice(deviceId: String): Boolean {
        return try {
            val deviceMap = usbManager.deviceList
            val targetDevice = deviceMap.values.find { it.deviceId.toString() == deviceId }
            
            if (targetDevice == null) {
                Log.e(TAG, "Device not found: $deviceId")
                return false
            }

            if (!isMagtekDevice(targetDevice.vendorId, targetDevice.productId)) {
                Log.e(TAG, "Not a Magtek device: $deviceId")
                return false
            }

            // Check if we have permission
            if (usbManager.hasPermission(targetDevice)) {
                connectToDeviceInternal(targetDevice)
                true
            } else {
                // Request permission
                val permissionIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    Intent(ACTION_USB_PERMISSION),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                usbManager.requestPermission(targetDevice, permissionIntent)
                Log.d(TAG, "Requesting USB permission for device: $deviceId")
                true // Permission request initiated
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error connecting to device: $deviceId", e)
            false
        }
    }

    private fun connectToDeviceInternal(device: UsbDevice): Boolean {
        return try {
            // Disconnect from current device first
            disconnect()

            val connection = usbManager.openDevice(device)
            if (connection == null) {
                Log.e(TAG, "Failed to open device connection")
                return false
            }

            // Find HID interface
            val hidInterface = findHidInterface(device)
            if (hidInterface == null) {
                Log.e(TAG, "No HID interface found")
                connection.close()
                return false
            }

            // Claim interface
            if (!connection.claimInterface(hidInterface, true)) {
                Log.e(TAG, "Failed to claim HID interface")
                connection.close()
                return false
            }

            // Find input endpoint
            val inputEndpoint = findInputEndpoint(hidInterface)
            if (inputEndpoint == null) {
                Log.e(TAG, "No input endpoint found")
                connection.releaseInterface(hidInterface)
                connection.close()
                return false
            }

            currentDevice = device
            currentConnection = connection
            currentInterface = hidInterface
            currentEndpoint = inputEndpoint
            currentDeviceId = device.deviceId.toString()

            Log.d(TAG, "Successfully connected to device: ${device.deviceName}")

            // Notify connection
            deviceConnectionCallback?.invoke(
                DeviceInfo(
                    deviceId = device.deviceId.toString(),
                    deviceName = getDeviceName(device.vendorId, device.productId),
                    vendorId = device.vendorId,
                    productId = device.productId,
                    serialNumber = device.serialNumber,
                    devicePath = device.deviceName,
                    isConnected = true
                )
            )

            true
        } catch (e: Exception) {
            Log.e(TAG, "Error in connectToDeviceInternal", e)
            false
        }
    }

    fun disconnect() {
        try {
            currentConnection?.let { connection ->
                currentInterface?.let { interface ->
                    connection.releaseInterface(interface)
                }
                connection.close()
            }

            currentDevice = null
            currentConnection = null
            currentInterface = null
            currentEndpoint = null
            currentDeviceId = null

            Log.d(TAG, "Disconnected from device")
        } catch (e: Exception) {
            Log.e(TAG, "Error during disconnect", e)
        }
    }

    fun isConnected(): Boolean {
        return currentDevice != null && currentConnection != null
    }

    fun startMonitoring() {
        if (isMonitoring) return

        isMonitoring = true
        monitoringScope.launch {
            Log.d(TAG, "Started device monitoring")
            
            while (isMonitoring && isActive) {
                try {
                    if (isConnected()) {
                        readFromDevice()
                    }
                    delay(50) // Check every 50ms
                } catch (e: Exception) {
                    if (isActive) {
                        Log.e(TAG, "Error in monitoring loop", e)
                    }
                }
            }
            
            Log.d(TAG, "Stopped device monitoring")
        }
    }

    fun stopMonitoring() {
        isMonitoring = false
    }

    private fun readFromDevice(): Boolean {
        val connection = currentConnection ?: return false
        val endpoint = currentEndpoint ?: return false
        val deviceId = currentDeviceId ?: return false

        return try {
            val buffer = ByteArray(256)
            val bytesRead = connection.bulkTransfer(endpoint, buffer, buffer.size, 10)

            if (bytesRead > 0) {
                val cardData = parseInputReport(buffer, bytesRead, deviceId)
                
                // Only notify if we have valid track data
                if (!cardData.track1.isNullOrEmpty() || 
                    !cardData.track2.isNullOrEmpty() || 
                    !cardData.track3.isNullOrEmpty()) {
                    cardSwipeCallback?.invoke(cardData)
                    Log.d(TAG, "Card swipe detected")
                }
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading from device", e)
            false
        }
    }

    private fun parseInputReport(data: ByteArray, length: Int, deviceId: String): CardData {
        val timestamp = System.currentTimeMillis()
        val rawResponse = data.take(length).joinToString(" ") { "%02x".format(it) }

        if (length < 2) {
            return CardData(null, null, null, deviceId, rawResponse, timestamp)
        }

        // Convert to string, skipping first byte (report ID)
        val dataString = String(
            data.slice(1 until length)
                .filter { it in 0x20..0x7E } // Printable ASCII only
                .toByteArray()
        )

        if (dataString.isEmpty()) {
            return CardData(null, null, null, deviceId, rawResponse, timestamp)
        }

        // Parse track data
        var track1: String? = null
        var track2: String? = null
        var track3: String? = null

        // Track 1: Starts with '%', ends with '?'
        val track1Start = dataString.indexOf('%')
        if (track1Start != -1) {
            val track1End = dataString.indexOf('?', track1Start)
            if (track1End != -1) {
                track1 = dataString.substring(track1Start, track1End + 1)
            }
        }

        // Track 2: Starts with ';', ends with '?'
        val track2Start = dataString.indexOf(';')
        if (track2Start != -1) {
            val track2End = dataString.indexOf('?', track2Start)
            if (track2End != -1) {
                track2 = dataString.substring(track2Start, track2End + 1)
            }
        }

        // Track 3: Less common, variable format
        // For now, we'll leave it null unless specific patterns are found

        return CardData(track1, track2, track3, deviceId, rawResponse, timestamp)
    }

    private fun findHidInterface(device: UsbDevice): UsbInterface? {
        for (i in 0 until device.interfaceCount) {
            val interface = device.getInterface(i)
            if (interface.interfaceClass == UsbConstants.USB_CLASS_HID) {
                return interface
            }
        }
        return null
    }

    private fun findInputEndpoint(interface: UsbInterface): UsbEndpoint? {
        for (i in 0 until interface.endpointCount) {
            val endpoint = interface.getEndpoint(i)
            if (endpoint.direction == UsbConstants.USB_DIR_IN &&
                endpoint.type == UsbConstants.USB_ENDPOINT_XFER_INT) {
                return endpoint
            }
        }
        return null
    }

    private fun isMagtekDevice(vendorId: Int, productId: Int): Boolean {
        return vendorId == MAGTEK_VENDOR_ID && productId in MAGTEK_PRODUCT_IDS
    }

    private fun getDeviceName(vendorId: Int, productId: Int): String {
        if (vendorId != MAGTEK_VENDOR_ID) {
            return "Unknown Device"
        }

        return when (productId) {
            0x0001 -> "Magtek Mini Swipe Reader"
            0x0002 -> "Magtek USB Swipe Reader"
            0x0003 -> "Magtek eDynamo"
            0x0004 -> "Magtek uDynamo"
            0x0010 -> "Magtek SureSwipe Reader"
            else -> "Magtek Card Reader (PID: 0x${productId.toString(16).padStart(4, '0')})"
        }
    }
}
