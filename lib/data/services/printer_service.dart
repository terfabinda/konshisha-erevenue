import 'dart:math';
import 'dart:typed_data';
import 'package:blue_thermal_printer_plus/blue_thermal_printer_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_strings.dart';
import '../models/receipt.dart';

class DiscoveredDevice {
  final String name;
  final String address;
  final int rssi;
  final bool isPrinter;

  DiscoveredDevice({
    required this.name,
    required this.address,
    required this.rssi,
    this.isPrinter = false,
  });
}

class PrinterDevice {
  final BluetoothDevice? device;
  final DiscoveredDevice? discoveredDevice;
  bool isConnected;
  bool isDiscovered;

  PrinterDevice({
    this.device,
    this.discoveredDevice,
    this.isConnected = false,
    this.isDiscovered = false,
  });

  String? get name => device?.name ?? discoveredDevice?.name;
  String? get address => device?.address ?? discoveredDevice?.address;
  int? get rssi => discoveredDevice?.rssi;
  bool get isPrinter => discoveredDevice?.isPrinter ?? false;
}

enum PrintMode { text, image }

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  static const _bleChannel = MethodChannel(
    AppStrings.methodChannel,
  );
  static const _confirmedPrintersKey = 'confirmed_printer_addresses';
  static const int _receiptWidth = 32;

  final BlueThermalPrinterPlus _bluetooth = BlueThermalPrinterPlus();
  BluetoothDevice? _connectedDevice;
  bool _isBluetoothEnabled = false;
  bool _isConnecting = false;
  bool _isScanning = false;
  bool _hasBluetoothPermissions = false;
  PrintMode _printMode = PrintMode.text;

  List<PrinterDevice> _pairedDevices = [];
  List<PrinterDevice> _discoveredDevices = [];
  final Set<String> _confirmedPrinterAddresses = {};

  List<PrinterDevice> get pairedDevices => _pairedDevices;
  List<PrinterDevice> get discoveredDevices => _discoveredDevices;
  List<PrinterDevice> get allDevices {
    final addresses = <String>{};
    final combined = <PrinterDevice>[];

    for (var device in _pairedDevices) {
      final addr = device.address ?? '';
      addresses.add(addr);
      combined.add(device);
    }

    for (var device in _discoveredDevices) {
      final addr = device.address ?? '';
      if (!addresses.contains(addr)) {
        combined.add(device);
      }
    }

    return combined;
  }

  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;
  bool get isBluetoothEnabled => _isBluetoothEnabled;
  bool get isConnecting => _isConnecting;
  bool get isScanning => _isScanning;
  bool get hasBluetoothPermissions => _hasBluetoothPermissions;
  PrintMode get printMode => _printMode;

  set printMode(PrintMode mode) {
    _printMode = mode;
    debugPrint('Print mode changed to: $mode');
  }

  Function(bool)? onBluetoothStateChanged;
  Function(BluetoothDevice?)? onDeviceConnected;
  Function(BluetoothDevice?)? onDeviceDisconnected;
  Function()? onScanStarted;
  Function()? onScanStopped;
  Function(List<PrinterDevice>)? onDevicesUpdated;

  Future<void> init() async {
    _bluetooth.onStateChanged.listen((state) {
      if (state == 1) {
        _isBluetoothEnabled = true;
      } else if (state == 0) {
        _isBluetoothEnabled = false;
      }
      onBluetoothStateChanged?.call(_isBluetoothEnabled);
      if (_isBluetoothEnabled) {
        getPairedDevices();
      }
    });

    await _checkBluetoothPermissions();
    await _loadConfirmedPrinters();
  }

  Future<void> _loadConfirmedPrinters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addresses = prefs.getStringList(_confirmedPrintersKey) ?? [];
      _confirmedPrinterAddresses.addAll(addresses);
      debugPrint('Loaded ${addresses.length} confirmed printers');
    } catch (e) {
      debugPrint('Error loading confirmed printers: $e');
    }
  }

  Future<void> _saveConfirmedPrinters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _confirmedPrintersKey,
        _confirmedPrinterAddresses.toList(),
      );
    } catch (e) {
      debugPrint('Error saving confirmed printers: $e');
    }
  }

  Future<bool> requestBluetoothPermissions() async {
    try {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      _hasBluetoothPermissions =
          statuses[Permission.bluetoothScan]!.isGranted &&
          statuses[Permission.bluetoothConnect]!.isGranted &&
          statuses[Permission.locationWhenInUse]!.isGranted;

      debugPrint(
        'Bluetooth permissions - Scan: ${statuses[Permission.bluetoothScan]}, '
        'Connect: ${statuses[Permission.bluetoothConnect]}, '
        'Location: ${statuses[Permission.locationWhenInUse]}',
      );

      return _hasBluetoothPermissions;
    } catch (e) {
      debugPrint('Error requesting Bluetooth permissions: $e');
      return false;
    }
  }

  Future<bool> _checkBluetoothPermissions() async {
    try {
      final scanStatus = await Permission.bluetoothScan.status;
      final connectStatus = await Permission.bluetoothConnect.status;

      _hasBluetoothPermissions =
          scanStatus.isGranted && connectStatus.isGranted;
      return _hasBluetoothPermissions;
    } catch (e) {
      debugPrint('Error checking Bluetooth permissions: $e');
      return false;
    }
  }

  Future<void> openApplicationSettings() async {
    await openAppSettings();
  }

  Future<bool> checkBluetoothEnabled() async {
    final isConn = await _bluetooth.isConnected;
    _isBluetoothEnabled = isConn ?? false;
    return _isBluetoothEnabled;
  }

  Future<List<PrinterDevice>> getPairedDevices() async {
    try {
      final devices = await _bluetooth.getBondedDevices();
      _pairedDevices = devices
          .map(
            (d) => PrinterDevice(
              device: d,
              isConnected: _connectedDevice?.address == d.address,
              isDiscovered: false,
            ),
          )
          .toList();

      debugPrint('Loaded ${_pairedDevices.length} paired devices from OS');
      for (var device in _pairedDevices) {
        debugPrint('  - Paired: ${device.name} (${device.address})');
      }

      onDevicesUpdated?.call(allDevices);
      return _pairedDevices;
    } catch (e) {
      debugPrint('Error getting paired devices: $e');
      return [];
    }
  }

  Future<bool> startDeviceDiscovery() async {
    if (_isScanning) return false;
    if (!_hasBluetoothPermissions) {
      debugPrint('Missing Bluetooth permissions for device discovery');
      return false;
    }

    try {
      _isScanning = true;
      _discoveredDevices.clear();
      onScanStarted?.call();

      final success =
          await _bleChannel.invokeMethod<bool>('startScan') ?? false;

      if (success) {
        await Future.delayed(const Duration(seconds: 10));
        await _collectDiscoveredDevices();
      }

      return success;
    } catch (e) {
      debugPrint('Error starting device discovery: $e');
      _isScanning = false;
      onScanStopped?.call();
      return false;
    } finally {
      _isScanning = false;
      onScanStopped?.call();
    }
  }

  Future<void> _collectDiscoveredDevices() async {
    try {
      final devices = await _bleChannel.invokeListMethod<Map>(
        'getDiscoveredDevices',
      );

      if (devices != null) {
        debugPrint('=== BLE Scan Results ===');
        debugPrint('Found ${devices.length} total devices');

        _discoveredDevices.clear();

        for (var deviceMap in devices) {
          final name = deviceMap['name'] as String? ?? 'Unknown';
          final address = deviceMap['address'] as String? ?? '';
          final rssi = deviceMap['rssi'] as int? ?? 0;
          final isPrinter = deviceMap['isPrinter'] as bool? ?? false;

          final discoveredDevice = DiscoveredDevice(
            name: name,
            address: address,
            rssi: rssi,
            isPrinter: isPrinter,
          );

          _discoveredDevices.add(
            PrinterDevice(
              discoveredDevice: discoveredDevice,
              isConnected: false,
              isDiscovered: true,
            ),
          );

          debugPrint(
            'Discovered: $name ($address) - Printer: $isPrinter, Signal: $rssi dBm',
          );
        }

        debugPrint('Total discovered devices: ${_discoveredDevices.length}');
        onDevicesUpdated?.call(allDevices);
      }
    } catch (e) {
      debugPrint('Error collecting discovered devices: $e');
    }
  }

  Future<void> stopDeviceDiscovery() async {
    if (!_isScanning) return;

    try {
      await _bleChannel.invokeMethod<bool>('stopScan');
      _isScanning = false;
      onScanStopped?.call();
    } catch (e) {
      debugPrint('Error stopping device discovery: $e');
      _isScanning = false;
    }
  }

  Future<List<PrinterDevice>> refreshDevices() async {
    await getPairedDevices();
    return allDevices;
  }

  Future<bool> connect(BluetoothDevice device) async {
    if (_isConnecting) return false;
    if (!_hasBluetoothPermissions) {
      debugPrint('Missing Bluetooth permissions to connect');
      return false;
    }

    _isConnecting = true;
    try {
      await disconnect();

      await _bluetooth.connect(device);
      _connectedDevice = device;

      for (var d in _pairedDevices) {
        d.isConnected = d.address == device.address;
      }
      for (var d in _discoveredDevices) {
        d.isConnected = d.address == device.address;
      }

      onDeviceConnected?.call(device);
      await getPairedDevices();
      return true;
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      try {
        await _bluetooth.disconnect();
        onDeviceDisconnected?.call(_connectedDevice);
      } catch (e) {
        debugPrint('Error disconnecting: $e');
      }
      _connectedDevice = null;

      for (var d in _pairedDevices) {
        d.isConnected = false;
      }
      for (var d in _discoveredDevices) {
        d.isConnected = false;
      }

      await getPairedDevices();
    }
  }

  Future<bool> initializePrinter() async {
    if (!isConnected) {
      debugPrint('No printer connected - cannot initialize');
      return false;
    }

    try {
      final initItems = [
        PrintItem(type: PrintItemType.newLine),
        PrintItem(type: PrintItemType.newLine),
      ];
      await _bluetooth.print(
        items: initItems,
        protocol: PrinterProtocol.escPos,
      );
      debugPrint('Printer initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing printer: $e');
      return false;
    }
  }

  Future<bool> sendRawData(String text) async {
    if (!isConnected) {
      debugPrint('No printer connected - cannot send data');
      return false;
    }

    try {
      debugPrint('Sending text to printer: $text');
      List<PrintItem> items = [PrintItem.text(text)];
      await _bluetooth.print(items: items, protocol: PrinterProtocol.escPos);
      debugPrint('Data sent successfully');
      return true;
    } catch (e) {
      debugPrint('Error sending data to printer: $e');
      return false;
    }
  }

  Future<bool> printTextFormatted(String text) async {
    if (!isConnected) {
      debugPrint('No printer connected');
      return false;
    }

    try {
      List<PrintItem> items = [PrintItem.text(text)];
      await _bluetooth.print(items: items, protocol: PrinterProtocol.escPos);

      if (_connectedDevice?.address != null) {
        markAsPrinterDevice(_connectedDevice?.address);
      }

      return true;
    } catch (e) {
      debugPrint('Error printing text: $e');
      return false;
    }
  }

  Future<bool> printReceiptImage(Uint8List receiptImage) async {
    if (!isConnected) {
      debugPrint('No printer connected');
      return false;
    }

    try {
      debugPrint('Printing receipt image: ${receiptImage.length} bytes');

      await _bluetooth.print(
        items: [PrintItem.image(receiptImage)],
        protocol: PrinterProtocol.escPos,
      );

      if (_connectedDevice?.address != null) {
        markAsPrinterDevice(_connectedDevice?.address);
      }

      debugPrint('Receipt image printed successfully');
      return true;
    } catch (e) {
      debugPrint('Error printing receipt image: $e');
      return false;
    }
  }

  String _generateReferenceNumber() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch % 100000;
    final suffix = random.nextInt(9999).toString().padLeft(4, '0');
    return '90000${timestamp.toString().padLeft(5, '0')}$suffix';
  }

  String _center(String text, {int width = _receiptWidth}) {
    if (text.length >= width) return text.substring(0, width);
    final padding = (width - text.length) ~/ 2;
    return ' ' * padding + text;
  }

  String _padRight(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    return text + ' ' * (width - text.length);
  }

  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return text.substring(0, maxLen - 2) + '..';
  }

  Future<bool> printFormattedReceipt(
    Receipt receipt, {
    String? lastName,
    String? firstName,
    String? tin,
  }) async {
    if (!isConnected) {
      debugPrint('No printer connected');
      return false;
    }

    try {
      debugPrint('Printing formatted receipt: ${receipt.categoryId}');

      final formattedAmount = 'N ${receipt.amount.toStringAsFixed(2)}';

      final dateFormat = DateFormat('dd/MM/yy HH:mm');
      final formattedDate = dateFormat.format(receipt.createdAt);
      final referenceNo = _generateReferenceNumber();

      final agentName = _truncate(_buildName(lastName, firstName), 18);
      final payerDisplay = receipt.payerName?.trim().isNotEmpty == true
          ? _truncate(receipt.payerName!, 18)
          : agentName;
      final categoryName = _truncate(receipt.categoryId ?? 'N/A', 20);
      final displayTin = _truncate(tin ?? 'N/A', 12);

      List<PrintItem> items = [];

      items.add(PrintItem.text(AppStrings.receiptHeader, size: 1, align: 1));
      items.add(PrintItem.text('TRANSACTION RECEIPT', align: 1));
      items.add(PrintItem.text('REF: $referenceNo', align: 1));

      items.add(PrintItem(type: PrintItemType.newLine));
      items.add(PrintItem.text('~' * _receiptWidth));

      items.add(PrintItem.text('REV: $categoryName'));
      items.add(PrintItem.text('DATE: $formattedDate'));

      items.add(PrintItem.text('PAYER: $payerDisplay'));
      items.add(PrintItem.text('TIN: $displayTin'));
      items.add(PrintItem(type: PrintItemType.newLine));

      items.add(PrintItem.text('-' * _receiptWidth));

      items.add(PrintItem.text('AMOUNT: $formattedAmount', size: 1));

      items.add(PrintItem(type: PrintItemType.newLine));
      items.add(PrintItem.text('~' * _receiptWidth));
      items.add(PrintItem.text('INV: $referenceNo', align: 1));
      items.add(PrintItem.text('STATUS: SUCCESS', align: 1));

      items.add(PrintItem.text('-' * _receiptWidth));
      items.add(PrintItem.text('AGENT: $agentName', align: 1));
      items.add(PrintItem.text('Powered By: Eternex Systems Ltd', align: 1));

      items.add(PrintItem(type: PrintItemType.newLine));
      items.add(PrintItem(type: PrintItemType.newLine));
      items.add(PrintItem(type: PrintItemType.paperCut));

      await _bluetooth.print(items: items, protocol: PrinterProtocol.escPos);

      if (_connectedDevice?.address != null) {
        markAsPrinterDevice(_connectedDevice?.address);
      }

      debugPrint('Receipt printed successfully');
      return true;
    } catch (e) {
      debugPrint('Error printing formatted receipt: $e');
      return false;
    }
  }

  String _buildName(String? lastName, String? firstName) {
    final ln = lastName?.trim().isNotEmpty == true ? lastName!.trim() : null;
    final fn = firstName?.trim().isNotEmpty == true ? firstName!.trim() : null;

    if (ln != null && fn != null) {
      return '$fn $ln';
    } else if (ln != null) {
      return ln;
    } else if (fn != null) {
      return fn;
    }
    return 'N/A';
  }

  Future<bool> printReceiptAsImage(
    Receipt receipt, {
    String? lastName,
    String? firstName,
    String? tin,
    required Uint8List imageBytes,
  }) async {
    if (!isConnected) {
      debugPrint('No printer connected');
      return false;
    }

    try {
      debugPrint('Printing receipt as image: ${imageBytes.length} bytes');

      if (imageBytes.isEmpty) {
        debugPrint('Error: Empty image data');
        return false;
      }

      if (imageBytes.length > 1024 * 1024) {
        debugPrint('Error: Image too large (${imageBytes.length} bytes)');
        return false;
      }

      debugPrint('Attempting to print image...');

      List<PrintItem> items = [];

      items.add(PrintItem.image(imageBytes));

      items.add(PrintItem(type: PrintItemType.newLine));
      items.add(PrintItem(type: PrintItemType.paperCut));

      debugPrint('Sending ${items.length} items to printer');
      await _bluetooth.print(items: items, protocol: PrinterProtocol.escPos);
      debugPrint('Print command sent');

      if (_connectedDevice?.address != null) {
        markAsPrinterDevice(_connectedDevice?.address);
      }

      debugPrint('Receipt image printed successfully');
      return true;
    } catch (e) {
      debugPrint('Error printing receipt as image: $e');
      return false;
    }
  }

  Future<bool> printText(String text) async {
    if (!isConnected) return false;

    try {
      return await printTextFormatted(text);
    } catch (e) {
      debugPrint('Error printing text: $e');
      return false;
    }
  }

  Future<bool> printNewLine() async {
    if (!isConnected) return false;

    try {
      final items = [PrintItem(type: PrintItemType.newLine)];
      await _bluetooth.print(items: items, protocol: PrinterProtocol.escPos);
      return true;
    } catch (e) {
      debugPrint('Error printing new line: $e');
      return false;
    }
  }

  void markAsPrinterDevice(String? address) {
    if (address != null && !_confirmedPrinterAddresses.contains(address)) {
      _confirmedPrinterAddresses.add(address);
      _saveConfirmedPrinters();
      debugPrint('Marked device as confirmed printer: $address');
      onDevicesUpdated?.call(allDevices);
    }
  }

  bool isConfirmedPrinter(String? address) {
    return address != null && _confirmedPrinterAddresses.contains(address);
  }

  Future<bool> printTestPage() async {
    if (!isConnected) {
      debugPrint('No printer connected - cannot print test page');
      return false;
    }

    try {
      debugPrint('Printing test page...');

      List<PrintItem> items = [
        PrintItem.text(_center('PRINTER TEST PAGE'), size: 1, align: 1),
        PrintItem.text(''),
        PrintItem.text(
          _padRight('Device:', 12) + (_connectedDevice?.name ?? 'Unknown'),
        ),
        PrintItem.text(
          _padRight('Address:', 12) + (_connectedDevice?.address ?? 'N/A'),
        ),
        PrintItem.text(
          _padRight('Time:', 12) +
              DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
        ),
        PrintItem.text(''),
        PrintItem.text('=' * _receiptWidth),
        PrintItem.text(_center('If you can read this,'), align: 1),
        PrintItem.text(_center('the printer is working!'), align: 1),
        PrintItem.text('=' * _receiptWidth),
      ];

      for (int i = 0; i < 4; i++) {
        items.add(PrintItem(type: PrintItemType.newLine));
      }

      await _bluetooth.print(items: items, protocol: PrinterProtocol.escPos);

      if (_connectedDevice?.address != null) {
        markAsPrinterDevice(_connectedDevice?.address);
      }
      debugPrint('Test page sent successfully');

      return true;
    } catch (e) {
      debugPrint('Error printing test page: $e');
      return false;
    }
  }

  void dispose() {
    disconnect();
  }
}
