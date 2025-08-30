# Web Setup Instructions for Magtek Card Reader Plugin

This document provides detailed setup instructions for web deployment using WebUSB API.

## Prerequisites

- Modern web browser with WebUSB support
- HTTPS connection (required for WebUSB)
- Flutter web development environment
- Magtek USB card reader device

## Browser Support

### Supported Browsers

| Browser | Version | Support | Notes |
|---------|---------|---------|-------|
| Chrome | 61+ | ✅ Full | Best support |
| Edge | 79+ | ✅ Full | Chromium-based |
| Opera | 48+ | ✅ Full | Chromium-based |
| Safari | ❌ | No support | WebUSB not implemented |
| Firefox | ❌ | No support | WebUSB behind flag |

### WebUSB Feature Detection

```javascript
if ('usb' in navigator) {
  console.log('WebUSB is supported');
} else {
  console.log('WebUSB is not supported');
}
```

## Security Requirements

### HTTPS Requirement

WebUSB **requires HTTPS** for security reasons:

- ✅ **Production**: `https://your-domain.com`
- ✅ **Local Development**: `http://localhost:*` (exception)
- ❌ **HTTP**: Not supported in production
- ❌ **Local IP**: `http://192.168.x.x` not supported

### Permissions Policy

Configure permissions in your HTML:

```html
<!-- Allow USB access for this origin -->
<meta http-equiv="Permissions-Policy" content="usb=()">
```

## Development Setup

### 1. Enable WebUSB in Development

For local development, use:

```bash
# Run Flutter web on localhost (WebUSB exception)
flutter run -d web-server --web-port 8080

# Or build and serve
flutter build web
# Serve on localhost with any HTTP server
```

### 2. Configure Web App

Update your `web/index.html`:

```html
<!DOCTYPE html>
<html>
<head>
  <!-- Required for WebUSB -->
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Permissions-Policy" content="usb=()">
  
  <!-- HTTPS enforcement -->
  <meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">
</head>
```

### 3. Browser Security Settings

For Chrome development, you may need to:

1. Enable experimental web features:
   - Go to `chrome://flags/`
   - Enable "Experimental Web Platform features"
   - Restart Chrome

2. Allow insecure localhost (if needed):
   - Go to `chrome://flags/`
   - Enable "Allow invalid certificates for resources loaded from localhost"

## User Experience Flow

### 1. Device Connection Process

```dart
// 1. User clicks "Connect Device" button
onPressed: () async {
  try {
    // 2. Browser shows device selection dialog
    final devices = await cardReader.getConnectedDevices();
    
    // 3. User selects Magtek device from list
    final success = await cardReader.connectToDevice(deviceId);
    
    if (success) {
      // 4. Device connected successfully
      print('Device connected!');
    }
  } catch (e) {
    // Handle user cancellation or errors
    print('Connection failed: $e');
  }
}
```

### 2. User Permission Flow

1. **User Action Required**: Connection must be triggered by user gesture
2. **Device Selection**: Browser shows native device picker
3. **Permission Grant**: User explicitly selects and grants access
4. **Persistent Access**: Permission persists for the session

### 3. Error Handling

```dart
try {
  await cardReader.connectToDevice(deviceId);
} catch (e) {
  if (e is PlatformNotSupportedException) {
    // Show browser not supported message
    showSnackBar('WebUSB not supported in this browser');
  } else if (e is DeviceConnectionException) {
    // Show connection failed message
    showSnackBar('Failed to connect to device');
  }
}
```

## Implementation Example

### Complete Web Integration

```dart
import 'package:magtek_card_reader/magtek_card_reader.dart';

class WebCardReaderDemo extends StatefulWidget {
  @override
  _WebCardReaderDemoState createState() => _WebCardReaderDemoState();
}

class _WebCardReaderDemoState extends State<WebCardReaderDemo> {
  final _cardReader = MagtekCardReader.instance;
  bool _isSupported = false;
  bool _isConnected = false;
  String _browserInfo = '';

  @override
  void initState() {
    super.initState();
    _checkWebUsbSupport();
    _setupCardReader();
  }

  Future<void> _checkWebUsbSupport() async {
    try {
      await _cardReader.initialize();
      final version = await _cardReader.getPlatformVersion();
      setState(() {
        _isSupported = true;
        _browserInfo = version ?? 'Unknown browser';
      });
    } catch (e) {
      setState(() {
        _isSupported = false;
        _browserInfo = 'WebUSB not supported';
      });
    }
  }

  Future<void> _setupCardReader() async {
    if (!_isSupported) return;

    // Listen for card swipes
    _cardReader.onCardSwipe.listen((cardData) {
      _showCardData(cardData);
    });

    // Listen for device connections
    _cardReader.onDeviceConnected.listen((deviceInfo) {
      setState(() {
        _isConnected = true;
      });
      _showSnackBar('Device connected: ${deviceInfo.deviceName}');
    });
  }

  Future<void> _connectDevice() async {
    if (!_isSupported) {
      _showSnackBar('WebUSB not supported in this browser');
      return;
    }

    try {
      // This will show browser's device selection dialog
      final devices = await _cardReader.getConnectedDevices();
      
      // Request device access (triggers user permission)
      final success = await _cardReader.connectToDevice('web-device');
      
      if (!success) {
        _showSnackBar('User cancelled device selection');
      }
    } catch (e) {
      _showSnackBar('Connection failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Magtek Web Demo'),
        backgroundColor: _isSupported ? Colors.green : Colors.red,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Browser support status
            Card(
              child: ListTile(
                leading: Icon(
                  _isSupported ? Icons.check_circle : Icons.error,
                  color: _isSupported ? Colors.green : Colors.red,
                ),
                title: Text('WebUSB Support'),
                subtitle: Text(_browserInfo),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Connection status
            Card(
              child: ListTile(
                leading: Icon(
                  _isConnected ? Icons.usb : Icons.usb_off,
                  color: _isConnected ? Colors.green : Colors.grey,
                ),
                title: Text('Device Status'),
                subtitle: Text(_isConnected ? 'Connected' : 'Not connected'),
                trailing: ElevatedButton(
                  onPressed: _isSupported && !_isConnected ? _connectDevice : null,
                  child: Text('Connect Device'),
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Instructions
            if (!_isSupported) ...[
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'WebUSB Not Supported',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please use Chrome, Edge, or Opera browser for WebUSB support.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'WebUSB Instructions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Click "Connect Device" button\n'
                        '2. Select your Magtek device from browser dialog\n'
                        '3. Swipe a card to test functionality',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

## Production Deployment

### 1. HTTPS Certificate

Ensure your web app is served over HTTPS:

```bash
# Example with Nginx
server {
    listen 443 ssl;
    server_name your-domain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        root /path/to/flutter/build/web;
        try_files $uri $uri/ /index.html;
    }
}
```

### 2. Content Security Policy

Configure CSP headers:

```html
<meta http-equiv="Content-Security-Policy" 
      content="default-src 'self'; 
               script-src 'self' 'unsafe-inline'; 
               style-src 'self' 'unsafe-inline';">
```

### 3. Permissions Policy

Set proper permissions:

```html
<meta http-equiv="Permissions-Policy" content="usb=()">
```

## Troubleshooting

### 1. WebUSB Not Available

**Symptoms**: `PlatformNotSupportedException`

**Solutions**:
- Use Chrome, Edge, or Opera browser
- Ensure HTTPS connection (or localhost)
- Check browser version compatibility
- Enable experimental web features in Chrome flags

### 2. Device Not Found

**Symptoms**: Empty device list or no device dialog

**Solutions**:
- Ensure device is properly connected
- Try different USB port/cable
- Check device power and functionality
- Verify device vendor/product ID matches filters

### 3. Permission Denied

**Symptoms**: User cancellation or access denied

**Solutions**:
- Ensure user action triggers connection (button click)
- Check for browser permission blocks
- Clear browser data and try again
- Verify HTTPS/localhost requirement

### 4. Connection Fails

**Symptoms**: Device selected but connection fails

**Solutions**:
- Check device is not in use by another application
- Verify USB interface claim permissions
- Try disconnecting and reconnecting device
- Check browser console for detailed errors

### 5. No Card Data

**Symptoms**: Device connects but no swipe events

**Solutions**:
- Verify card reader functionality with other software
- Check USB data connection (not just power)
- Ensure proper endpoint communication
- Try different card types and swipe speeds

## Browser-Specific Notes

### Chrome/Chromium

- Best WebUSB support
- Regular security updates
- Enable experimental features for development

### Microsoft Edge

- WebUSB supported since version 79
- Similar behavior to Chrome
- Good for enterprise deployment

### Opera

- WebUSB supported since version 48
- Based on Chromium engine
- May have occasional compatibility issues

### Safari

- **No WebUSB support**
- No timeline for implementation
- Use alternative browsers on macOS/iOS

### Firefox

- WebUSB behind experimental flag
- Not recommended for production
- Limited testing and support

## Performance Considerations

### 1. Polling Frequency

WebUSB polling is optimized for web performance:

```dart
// Polling every 50ms (configurable)
Timer.periodic(Duration(milliseconds: 50), (_) {
  _readFromDevice();
});
```

### 2. Memory Management

Proper cleanup to prevent memory leaks:

```dart
@override
void dispose() {
  _stopMonitoring();
  _cardSwipeController.close();
  _deviceConnectionController.close();
  super.dispose();
}
```

### 3. Error Handling

Graceful degradation for unsupported browsers:

```dart
Widget build(BuildContext context) {
  if (!isWebUsbSupported) {
    return UnsupportedBrowserWidget();
  }
  return CardReaderWidget();
}
```

## Security Best Practices

### 1. Data Protection

- Never log or store sensitive card data
- Implement proper data masking
- Use secure transmission protocols
- Follow PCI DSS guidelines

### 2. User Consent

- Clear permission requests
- Explain why USB access is needed
- Provide opt-out mechanisms
- Respect user privacy choices

### 3. Origin Validation

- Restrict to specific origins
- Implement proper CORS policies
- Validate all input data
- Use content security policies

This comprehensive web setup guide should help you successfully deploy the Magtek Card Reader plugin for web browsers with WebUSB support.
