import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image/image.dart' as img;
import '../../../data/models/receipt.dart';
import '../../../data/models/receipt_service.dart';
import '../../../data/models/merchant_profile_service.dart';
import '../../../data/services/printer_service.dart';
import '../../../data/models/merchant_profile.dart';
import '../../../core/models/print_log.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/print_history_service.dart';
import '../../../core/constants/default_categories.dart';
import '../../widgets/receipt_widget.dart';

class PrintReceiptsScreen extends StatefulWidget {
  const PrintReceiptsScreen({super.key});

  @override
  State<PrintReceiptsScreen> createState() => _PrintReceiptsScreenState();
}

class _PrintReceiptsScreenState extends State<PrintReceiptsScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final PrinterService _printerService = PrinterService();
  late TextEditingController _amountController;
  late TextEditingController _payerController;

  String? _selectedCategory;
  List<Receipt> _receipts = [];
  bool _isLoading = true;
  bool _isPrinting = false;
  bool _isSyncing = false;
  int _pendingCount = 0;
  MerchantProfile? _profile;
  StreamSubscription? _connectivitySub;

  static const int _pageSize = 10;
  int _currentPage = 1;

  List<Receipt> get _sortedReceipts {
    final sorted = List<Receipt>.from(_receipts);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  List<Receipt> get _displayedReceipts {
    final sorted = _sortedReceipts;
    final end = _currentPage * _pageSize;
    return sorted.take(end).toList();
  }

  bool get _hasMore => _currentPage * _pageSize < _receipts.length;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _payerController = TextEditingController();
    _loadData();
    _initPrinter();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
      if (online) _loadData();
    });
  }

  Future<void> _initPrinter() async {
    await _printerService.init();
  }

  Future<void> _loadData() async {
    try {
      final receipts = await ReceiptService.getAllReceipts();
      _profile = await MerchantProfileService.loadProfile();
      _pendingCount = await ReceiptService.getPendingReceiptCount();
      setState(() {
        _receipts = receipts;
        _currentPage = 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading receipts: $e')));
      }
    }
  }

  Future<void> _syncPending() async {
    setState(() => _isSyncing = true);
    try {
      final before = await ReceiptService.getPendingReceiptCount();
      if (before == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No pending receipts to sync'), backgroundColor: Colors.blueGrey),
          );
        }
        return;
      }
      final synced = await ReceiptService.syncPendingReceipts();
      _pendingCount = await ReceiptService.getPendingReceiptCount();
      if (mounted) {
        if (synced > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Synced $synced receipt(s) successfully'), backgroundColor: Colors.green),
          );
        } else if (_pendingCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to sync right now. Your receipt is saved locally and will upload automatically.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No pending receipts to sync'), backgroundColor: Colors.blueGrey),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
      await _loadData();
      _pendingCount = await ReceiptService.getPendingReceiptCount();
      if (mounted) setState(() {});
    }
  }

  void _showAddReceiptDialog() {
    _selectedCategory = null;
    _payerController.clear();
    _amountController.clear();
    final parentScaffold = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) {
        var isAdding = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text("Add New Receipt"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    hint: const Text('Select Revenue Head'),
                    isExpanded: true,
                    items: defaultRevenueCategories
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(
                              cat,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                    },
                    decoration: const InputDecoration(
                      labelText: "Revenue Head",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Amount (₦)",
                      border: OutlineInputBorder(),
                      prefix: Text("₦ "),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _payerController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: "Payer's Name (Optional)",
                      border: OutlineInputBorder(),
                      hintText: "Leave blank to use agent name",
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isAdding ? null : () => Navigator.pop(dialogContext),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: isAdding
                    ? null
                    : () => _addReceipt(
                          dialogContext,
                          parentScaffold,
                          () => setDialogState(() => isAdding = true),
                        ),
                child: isAdding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Add Receipt"),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addReceipt(BuildContext dialogContext, ScaffoldMessengerState parentScaffold, VoidCallback setAdding) async {
    setAdding();

    if (_selectedCategory == null || _amountController.text.isEmpty) {
      parentScaffold.showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      Navigator.pop(dialogContext);
      return;
    }

    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        if (!mounted) return;
        parentScaffold.showSnackBar(
          const SnackBar(content: Text('Session expired. Please login again.')),
        );
        Navigator.pop(dialogContext);
        return;
      }

      final payerName = _payerController.text.trim().isEmpty
          ? 'Walk-in'
          : _payerController.text.trim();

      final receipt = Receipt(
        id: 'RCP-${DateTime.now().millisecondsSinceEpoch}',
        agencyId: user.agencyId ?? 'default',
        createdBy: user.uid,
        payerName: payerName,
        categoryId: _selectedCategory ?? '',
        description: _selectedCategory ?? '',
        amount: double.parse(_amountController.text),
        totalAmount: double.parse(_amountController.text),
        deviceFingerprint: 'unknown',
        createdAt: DateTime.now(),
      );

      await ReceiptService.addReceipt(receipt);
      _amountController.clear();
      _payerController.clear();
      _selectedCategory = null;

      if (!mounted) return;
      Navigator.pop(dialogContext);
      await _loadData();

      if (!mounted) return;
      parentScaffold.showSnackBar(
        const SnackBar(
          content: Text('Receipt added successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(dialogContext);
      parentScaffold.showSnackBar(SnackBar(content: Text('Error adding receipt: $e')));
    }
  }

  Future<void> _previewAndPrint(Receipt receipt) async {
    if (!_printerService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No printer connected. Please connect a printer first.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PreviewSheet(
        receipt: receipt,
        profile: _profile,
        screenshotController: _screenshotController,
        printerService: _printerService,
        onPrinted: () => _loadData(),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _payerController.dispose();
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayReceipts = _receipts.where((r) => r.isToday).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Print Receipts"),
        backgroundColor: Colors.green.shade800,
        actions: [
          if (_pendingCount > 0)
            IconButton(
              onPressed: _isSyncing ? null : _syncPending,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Badge(
                      label: Text('$_pendingCount'),
                      child: const Icon(Icons.cloud_upload, color: Colors.white),
                    ),
              tooltip: 'Sync pending receipts',
            ),
          if (_printerService.isConnected)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bluetooth_connected,
                    size: 16,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Connected',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _quoteCard(
                          "Total Receipts",
                          _receipts.length.toString(),
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _quoteCard(
                          "Today",
                          todayReceipts.length.toString(),
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _showAddReceiptDialog,
                      icon: const Icon(Icons.add),
                      label: const Text("New Receipt"),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Recent Receipts",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  if (_receipts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No receipts yet",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._displayedReceipts.map((receipt) {
                      return _receiptTile(receipt);
                    }),
                  if (_hasMore)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => _currentPage++);
                          },
                          child: Text(
                            'Show more (${_receipts.length - _currentPage * _pageSize} remaining)',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _quoteCard(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _receiptTile(Receipt receipt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                receipt.description,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(receipt.id, style: const TextStyle(fontSize: 12)),
              trailing: Text(
                ReceiptService.formatCurrency(receipt.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(receipt.status == 'printed' ? "Printed" : "Active"),
                  backgroundColor: receipt.status == 'printed'
                      ? Colors.green.shade100
                      : Colors.blue.shade100,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: receipt.status == 'printed' ? Colors.green : Colors.blue,
                  ),
                ),
                TextButton.icon(
                  onPressed: _isPrinting
                      ? null
                      : () => _previewAndPrint(receipt),
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print, size: 18, color: Colors.white),
                  label: const Text(
                    "Print",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSheet extends StatefulWidget {
  final Receipt receipt;
  final MerchantProfile? profile;
  final ScreenshotController screenshotController;
  final PrinterService printerService;
  final VoidCallback onPrinted;

  const _PreviewSheet({
    required this.receipt,
    required this.profile,
    required this.screenshotController,
    required this.printerService,
    required this.onPrinted,
  });

  @override
  State<_PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends State<_PreviewSheet> {
  bool _isPrinting = false;
  int _numberOfPages = 1;
  int _copiesPerPage = 1;
  PrintMode _printMode = PrintMode.text;

  Future<Uint8List?> _captureReceiptImage() async {
    try {
      final image = await widget.screenshotController.capture(
        pixelRatio: 1.5,
        delay: const Duration(milliseconds: 100),
      );

      if (image == null) return null;

      final decodedImage = img.decodeImage(image);
      if (decodedImage == null) return null;

      final grayscale = img.grayscale(decodedImage);
      final resized = img.copyResize(grayscale, width: 300);

      final jpgImage = img.encodeJpg(resized, quality: 80);
      debugPrint(
        'Processed image: ${resized.width}x${resized.height}, size: ${jpgImage.length} bytes, format: JPG',
      );

      return Uint8List.fromList(jpgImage);
    } catch (e) {
      debugPrint('Error capturing receipt: $e');
      return null;
    }
  }

  Future<void> _printReceipt() async {
    setState(() => _isPrinting = true);

    final user = await AuthService.getCurrentUser();
    final reprintCount = await _safeReprintCount(widget.receipt.id);
    final logId = 'PRINT-${DateTime.now().millisecondsSinceEpoch}';

    int totalPrints = _numberOfPages * _copiesPerPage;
    int successCount = 0;
    String? errorMessage;
    Uint8List? imageBytes;

    if (_printMode == PrintMode.image) {
      imageBytes = await _captureReceiptImage();
      if (imageBytes == null) {
        errorMessage = 'Failed to capture receipt image';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to capture receipt image'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isPrinting = false);
        return;
      }
    }

    for (int i = 0; i < totalPrints; i++) {
      bool success;

      if (_printMode == PrintMode.image) {
        success = await widget.printerService.printReceiptAsImage(
          widget.receipt,
          firstName: widget.profile?.firstName,
          lastName: widget.profile?.lastName,
          tin: widget.profile?.tin,
          imageBytes: imageBytes!,
        );
      } else {
        success = await widget.printerService.printFormattedReceipt(
          widget.receipt,
          firstName: widget.profile?.firstName,
          lastName: widget.profile?.lastName,
          tin: widget.profile?.tin,
        );
      }

      if (success) {
        successCount++;
      } else {
        errorMessage = 'Failed to print copy ${i + 1}/$totalPrints';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;
      }
    }

    // Log print result to Firestore (best-effort, never blocks printing)
    if (user != null) {
      try {
        final printLog = PrintLog(
          id: logId,
          receiptId: widget.receipt.id,
          receiptRef: widget.receipt.id,
          printedAt: DateTime.now(),
          copies: successCount,
          printMode: _printMode == PrintMode.image ? 'image' : 'text',
          printedBy: user.uid,
          agencyId: user.agencyId,
          success: successCount == totalPrints,
          errorMessage: errorMessage,
          isReprint: reprintCount > 0 || widget.receipt.status == 'printed',
        );
        await PrintHistoryService.logPrint(printLog);
      } catch (_) {
        // Firestore write failure must never prevent printing
      }
    }

    if (successCount == totalPrints) {
      widget.onPrinted();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully printed $totalPrints copies!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Printed $successCount out of $totalPrints copies'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (mounted) setState(() => _isPrinting = false);
  }

  Future<int> _safeReprintCount(String receiptId) async {
    try {
      return await PrintHistoryService.getReprintCount(receiptId);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Receipt Preview",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Screenshot(
              controller: widget.screenshotController,
              child: ReceiptWidget(
                receipt: widget.receipt,
                merchantName: widget.profile?.fullName,
                agentId: widget.profile?.agentId,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Print Settings",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Number of Pages",
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _numberOfPages > 1
                                      ? () => setState(() => _numberOfPages--)
                                      : null,
                                  icon: const Icon(Icons.remove_circle),
                                  iconSize: 24,
                                ),
                                Expanded(
                                  child: TextField(
                                    textAlign: TextAlign.center,
                                    controller: TextEditingController(
                                      text: _numberOfPages.toString(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _numberOfPages++),
                                  icon: const Icon(Icons.add_circle),
                                  iconSize: 24,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Copies per Page",
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _copiesPerPage > 1
                                      ? () => setState(() => _copiesPerPage--)
                                      : null,
                                  icon: const Icon(Icons.remove_circle),
                                  iconSize: 24,
                                ),
                                Expanded(
                                  child: TextField(
                                    textAlign: TextAlign.center,
                                    controller: TextEditingController(
                                      text: _copiesPerPage.toString(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _copiesPerPage++),
                                  icon: const Icon(Icons.add_circle),
                                  iconSize: 24,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      'Total: ${_numberOfPages * _copiesPerPage} receipt(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<PrintMode>(
                          segments: const [
                            ButtonSegment(
                              value: PrintMode.text,
                              label: Text('Text'),
                              icon: Icon(Icons.text_fields),
                            ),
                            ButtonSegment(
                              value: PrintMode.image,
                              label: Text('Image'),
                              icon: Icon(Icons.image),
                            ),
                          ],
                          selected: {_printMode},
                          onSelectionChanged: (selection) {
                            setState(() => _printMode = selection.first);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _printMode == PrintMode.image
                              ? Icons.image
                              : Icons.receipt_long,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _printMode == PrintMode.image
                                ? 'Captures receipt as image for better quality'
                                : 'Compact text output, uses less paper',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPrinting ? null : _printReceipt,
                          icon: _isPrinting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.print),
                          label: Text(_isPrinting ? "Printing..." : "Print"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
