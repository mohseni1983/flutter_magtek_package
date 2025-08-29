package com.example.magtek_card_reader

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.util.Log

/** MagtekCardReaderPlugin */
class MagtekCardReaderPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  companion object {
    private const val TAG = "MagtekCardReaderPlugin"
  }

  private lateinit var methodChannel: MethodChannel
  private lateinit var cardSwipeEventChannel: EventChannel
  private lateinit var deviceEventChannel: EventChannel
  
  private var cardSwipeEventSink: EventChannel.EventSink? = null
  private var deviceEventSink: EventChannel.EventSink? = null
  
  private var context: Context? = null
  private var deviceManager: AndroidUsbDeviceManager? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    
    // Set up method channel
    methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "magtek_card_reader")
    methodChannel.setMethodCallHandler(this)
    
    // Set up event channels
    cardSwipeEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "magtek_card_reader/card_swipe")
    cardSwipeEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        cardSwipeEventSink = events
      }
      
      override fun onCancel(arguments: Any?) {
        cardSwipeEventSink = null
      }
    })
    
    deviceEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "magtek_card_reader/device_events")
    deviceEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        deviceEventSink = events
      }
      
      override fun onCancel(arguments: Any?) {
        deviceEventSink = null
      }
    })
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "initialize" -> {
        handleInitialize(result)
      }
      "dispose" -> {
        handleDispose(result)
      }
      "getConnectedDevices" -> {
        handleGetConnectedDevices(result)
      }
      "connectToDevice" -> {
        handleConnectToDevice(call, result)
      }
      "disconnect" -> {
        handleDisconnect(result)
      }
      "isConnected" -> {
        handleIsConnected(result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun handleInitialize(result: Result) {
    try {
      val ctx = context
      if (ctx == null) {
        result.error("NO_CONTEXT", "Application context not available", null)
        return
      }

      deviceManager = AndroidUsbDeviceManager(ctx)
      
      if (!deviceManager!!.initialize()) {
        result.error("INITIALIZATION_FAILED", "Failed to initialize USB device manager", null)
        return
      }

      // Set up callbacks
      deviceManager!!.cardSwipeCallback = { cardData ->
        val eventMap = mapOf(
          "track1" to cardData.track1,
          "track2" to cardData.track2,
          "track3" to cardData.track3,
          "deviceId" to cardData.deviceId,
          "rawResponse" to cardData.rawResponse,
          "timestamp" to cardData.timestamp
        )
        cardSwipeEventSink?.success(eventMap)
      }

      deviceManager!!.deviceConnectionCallback = { deviceInfo ->
        val deviceMap = mapOf(
          "deviceId" to deviceInfo.deviceId,
          "deviceName" to deviceInfo.deviceName,
          "vendorId" to deviceInfo.vendorId,
          "productId" to deviceInfo.productId,
          "serialNumber" to deviceInfo.serialNumber,
          "devicePath" to deviceInfo.devicePath,
          "isConnected" to deviceInfo.isConnected
        )
        
        val eventMap = mapOf(
          "type" to "device_connected",
          "device" to deviceMap
        )
        deviceEventSink?.success(eventMap)
      }

      deviceManager!!.startMonitoring()
      
      Log.d(TAG, "Device manager initialized successfully")
      result.success(null)
    } catch (e: Exception) {
      Log.e(TAG, "Error initializing device manager", e)
      result.error("INITIALIZATION_ERROR", e.message, null)
    }
  }

  private fun handleDispose(result: Result) {
    try {
      deviceManager?.cleanup()
      deviceManager = null
      Log.d(TAG, "Device manager disposed")
      result.success(null)
    } catch (e: Exception) {
      Log.e(TAG, "Error disposing device manager", e)
      result.error("DISPOSAL_ERROR", e.message, null)
    }
  }

  private fun handleGetConnectedDevices(result: Result) {
    try {
      val manager = deviceManager
      if (manager == null) {
        result.error("NOT_INITIALIZED", "Device manager not initialized", null)
        return
      }

      val devices = manager.getConnectedDevices()
      val deviceList = devices.map { device ->
        mapOf(
          "deviceId" to device.deviceId,
          "deviceName" to device.deviceName,
          "vendorId" to device.vendorId,
          "productId" to device.productId,
          "serialNumber" to device.serialNumber,
          "devicePath" to device.devicePath,
          "isConnected" to device.isConnected
        )
      }

      result.success(deviceList)
    } catch (e: Exception) {
      Log.e(TAG, "Error getting connected devices", e)
      result.error("GET_DEVICES_ERROR", e.message, null)
    }
  }

  private fun handleConnectToDevice(call: MethodCall, result: Result) {
    try {
      val manager = deviceManager
      if (manager == null) {
        result.error("NOT_INITIALIZED", "Device manager not initialized", null)
        return
      }

      val deviceId = call.argument<String>("deviceId")
      if (deviceId == null) {
        result.error("INVALID_ARGUMENTS", "deviceId is required", null)
        return
      }

      val success = manager.connectToDevice(deviceId)
      result.success(success)
    } catch (e: Exception) {
      Log.e(TAG, "Error connecting to device", e)
      result.error("CONNECTION_ERROR", e.message, null)
    }
  }

  private fun handleDisconnect(result: Result) {
    try {
      val manager = deviceManager
      if (manager == null) {
        result.error("NOT_INITIALIZED", "Device manager not initialized", null)
        return
      }

      manager.disconnect()
      result.success(null)
    } catch (e: Exception) {
      Log.e(TAG, "Error disconnecting", e)
      result.error("DISCONNECT_ERROR", e.message, null)
    }
  }

  private fun handleIsConnected(result: Result) {
    try {
      val manager = deviceManager
      if (manager == null) {
        result.success(false)
        return
      }

      val connected = manager.isConnected()
      result.success(connected)
    } catch (e: Exception) {
      Log.e(TAG, "Error checking connection status", e)
      result.error("CONNECTION_CHECK_ERROR", e.message, null)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    cardSwipeEventChannel.setStreamHandler(null)
    deviceEventChannel.setStreamHandler(null)
    
    deviceManager?.cleanup()
    deviceManager = null
    context = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    // Activity binding if needed for permissions
  }

  override fun onDetachedFromActivityForConfigChanges() {
    // Handle configuration changes
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    // Handle configuration changes
  }

  override fun onDetachedFromActivity() {
    // Activity detached
  }
}
