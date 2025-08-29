import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:magtek_card_reader/magtek_card_reader.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magtek Card Reader Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const CardReaderHomePage(),
    );
  }
}

class CardReaderHomePage extends StatefulWidget {
  const CardReaderHomePage({super.key});

  @override
  State<CardReaderHomePage> createState() => _CardReaderHomePageState();
}

class _CardReaderHomePageState extends State<CardReaderHomePage> {
  final _cardReader = MagtekCardReader.instance;
  
  String _platformVersion = 'Unknown';
  List<DeviceInfo> _devices = [];
  bool _isInitialized = false;
  bool _isConnected = false;
  String? _connectedDeviceId;
  List<CardData> _cardHistory = [];
  String _statusMessage = 'Not initialized';
  
  late StreamSubscription<CardData> _cardSwipeSubscription;
  late StreamSubscription<DeviceInfo> _deviceConnectionSubscription;
  late StreamSubscription<MagtekException> _errorSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCardReader();
  }

  @override
  void dispose() {
    _cardSwipeSubscription.cancel();
    _deviceConnectionSubscription.cancel();
    _errorSubscription.cancel();
    _cardReader.dispose();
    super.dispose();
  }

  Future<void> _initializeCardReader() async {
    try {
      // Get platform version
      final platformVersion = await _cardReader.getPlatformVersion() ?? 'Unknown platform version';
      
      // Set up event listeners
      _cardSwipeSubscription = _cardReader.onCardSwipe.listen(_onCardSwipe);
      _deviceConnectionSubscription = _cardReader.onDeviceConnected.listen(_onDeviceConnected);
      _errorSubscription = _cardReader.onError.listen(_onError);
      
      // Initialize the card reader
      await _cardReader.initialize();
      
      // Get initial device list
      await _refreshDevices();
      
      setState(() {
        _platformVersion = platformVersion;
        _isInitialized = true;
        _statusMessage = 'Initialized successfully';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize: $e';
      });
    }
  }

  Future<void> _refreshDevices() async {
    try {
      final devices = await _cardReader.getConnectedDevices();
      final isConnected = await _cardReader.isConnected();
      
      setState(() {
        _devices = devices;
        _isConnected = isConnected;
        if (!isConnected) {
          _connectedDeviceId = null;
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to refresh devices: $e';
      });
    }
  }

  Future<void> _connectToDevice(String deviceId) async {
    try {
      final success = await _cardReader.connectToDevice(deviceId);
      if (success) {
        setState(() {
          _isConnected = true;
          _connectedDeviceId = deviceId;
          _statusMessage = 'Connected to device';
        });
        await _refreshDevices();
      } else {
        setState(() {
          _statusMessage = 'Failed to connect to device';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection error: $e';
      });
    }
  }

  Future<void> _disconnectDevice() async {
    try {
      await _cardReader.disconnect();
      setState(() {
        _isConnected = false;
        _connectedDeviceId = null;
        _statusMessage = 'Disconnected from device';
      });
      await _refreshDevices();
    } catch (e) {
      setState(() {
        _statusMessage = 'Disconnect error: $e';
      });
    }
  }

  void _onCardSwipe(CardData cardData) {
    setState(() {
      _cardHistory.insert(0, cardData);
      if (_cardHistory.length > 10) {
        _cardHistory.removeLast();
      }
      _statusMessage = 'Card swiped successfully';
    });
    
    // Show card swipe dialog
    _showCardDataDialog(cardData);
  }

  void _onDeviceConnected(DeviceInfo deviceInfo) {
    setState(() {
      _statusMessage = 'Device connected: ${deviceInfo.deviceName}';
    });
    _refreshDevices();
  }

  void _onError(MagtekException error) {
    setState(() {
      _statusMessage = 'Error: ${error.message}';
    });
  }

  void _showCardDataDialog(CardData cardData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Card Swiped'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cardData.cardBrand != null) ...[
                  Text('Card Brand: ${cardData.cardBrand}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                ],
                if (cardData.maskedAccountNumber != null) ...[
                  Text('Account: ${cardData.maskedAccountNumber}'),
                  const SizedBox(height: 8),
                ],
                if (cardData.cardholderName != null) ...[
                  Text('Cardholder: ${cardData.cardholderName}'),
                  const SizedBox(height: 8),
                ],
                if (cardData.expirationDate != null) ...[
                  Text('Expiration: ${cardData.expirationDate}'),
                  const SizedBox(height: 8),
                ],
                Text('Valid Card: ${cardData.isValidPaymentCard ? "Yes" : "No"}'),
                const SizedBox(height: 8),
                Text('Decoded Tracks: ${cardData.decodedTracks.map((t) => t.trackNumber).join(", ")}'),
                const SizedBox(height: 8),
                Text('Timestamp: ${DateTime.fromMillisecondsSinceEpoch(cardData.timestamp.toInt())}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showRawDataDialog(cardData);
              },
              child: const Text('Show Raw Data'),
            ),
          ],
        );
      },
    );
  }

  void _showRawDataDialog(CardData cardData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Raw Card Data'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cardData.track1?.rawData != null) ...[
                  const Text('Track 1:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(cardData.track1!.rawData!, style: const TextStyle(fontFamily: 'monospace')),
                  const SizedBox(height: 8),
                ],
                if (cardData.track2?.rawData != null) ...[
                  const Text('Track 2:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(cardData.track2!.rawData!, style: const TextStyle(fontFamily: 'monospace')),
                  const SizedBox(height: 8),
                ],
                if (cardData.track3?.rawData != null) ...[
                  const Text('Track 3:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(cardData.track3!.rawData!, style: const TextStyle(fontFamily: 'monospace')),
                  const SizedBox(height: 8),
                ],
                if (cardData.rawResponse != null) ...[
                  const Text('Raw Response:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(cardData.rawResponse!, style: const TextStyle(fontFamily: 'monospace')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Magtek Card Reader Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Platform: $_platformVersion'),
                    Text('Initialized: ${_isInitialized ? "Yes" : "No"}'),
                    Text('Connected: ${_isConnected ? "Yes" : "No"}'),
                    if (_connectedDeviceId != null) Text('Device: $_connectedDeviceId'),
                    const SizedBox(height: 8),
                    Text('Message: $_statusMessage', style: const TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Devices', style: Theme.of(context).textTheme.headlineSmall),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _refreshDevices,
                              icon: const Icon(Icons.refresh),
                              tooltip: 'Refresh devices',
                            ),
                            if (_isConnected)
                              IconButton(
                                onPressed: _disconnectDevice,
                                icon: const Icon(Icons.link_off),
                                tooltip: 'Disconnect',
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_devices.isEmpty)
                      const Text('No Magtek devices found')
                    else
                      ..._devices.map((device) => Card(
                        elevation: 2,
                        child: ListTile(
                          leading: Icon(
                            device.isConnected ? Icons.usb_rounded : Icons.usb_off,
                            color: device.isConnected ? Colors.green : Colors.grey,
                          ),
                          title: Text(device.displayName),
                          subtitle: Text('${device.deviceType}\nVID: 0x${device.vendorId.toRadixString(16)} PID: 0x${device.productId.toRadixString(16)}'),
                          trailing: device.isConnected 
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : ElevatedButton(
                                onPressed: () => _connectToDevice(device.deviceId),
                                child: const Text('Connect'),
                              ),
                          isThreeLine: true,
                        ),
                      )).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Card Swipe History', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      if (_cardHistory.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.credit_card, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No cards swiped yet'),
                                SizedBox(height: 8),
                                Text('Connect to a device and swipe a card to see data here'),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: _cardHistory.length,
                            itemBuilder: (context, index) {
                              final cardData = _cardHistory[index];
                              return Card(
                                elevation: 2,
                                child: ListTile(
                                  leading: Icon(
                                    Icons.credit_card,
                                    color: cardData.isValidPaymentCard ? Colors.green : Colors.orange,
                                  ),
                                  title: Text(cardData.maskedAccountNumber ?? 'Unknown Card'),
                                  subtitle: Text(
                                    '${cardData.cardBrand ?? "Unknown"} • '
                                    '${DateTime.fromMillisecondsSinceEpoch(cardData.timestamp.toInt()).toString().substring(11, 19)}'
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () => _showCardDataDialog(cardData),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
