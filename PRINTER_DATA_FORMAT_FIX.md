# Printer Data Format Fix - ESC/POS Proper Implementation

## What Was Changed

The printer wasn't working because the data format was incomplete. Thermal printers need:
1. **Initialization commands** - Set up the printer
2. **Print data** - The actual content with proper formatting
3. **Termination commands** - Cut paper, feed lines, flush buffers

The old code was using a simple print wrapper that wasn't generating complete ESC/POS protocol.

## What We Fixed

### 1. Added `esc_pos_utils` Integration
Instead of basic `PrintItem` wrappers, we now use proper ESC/POS command generation with `Generator` class:

```dart
// Before (incomplete):
List<PrintItem> items = [PrintItem.text(text)];
await _bluetooth.print(items: items, protocol: PrinterProtocol.escPos);

// After (complete):
final generator = Generator(PaperSize.mm58);
List<int> bytes = [];
bytes.addAll(generator.reset());        // Initialize printer
bytes.addAll(generator.text(text));     // Print text
bytes.addAll(generator.feed(2));        // Add line feeds
bytes.addAll(generator.cut());          // Cut paper
await sendRawData(bytes);               // Send all bytes
```

### 2. New Methods Added

#### `initializePrinter()`
Call this once after connecting to set up the printer:
```dart
await printerService.connect(device);
await printerService.initializePrinter();
```

#### `sendRawData(List<int> bytes)`
Sends raw ESC/POS formatted bytes directly to the printer:
```dart
final generator = Generator(PaperSize.mm58);
List<int> bytes = [];
bytes.addAll(generator.text("Hello"));
bytes.addAll(generator.cut());
await printerService.sendRawData(bytes);
```

#### `printTextFormatted(String text, {int fontSize = 0})`
Print text with optional font size enlargement:
```dart
await printerService.printTextFormatted("Large Text", fontSize: 2);
```

### 3. Updated Existing Methods

#### `printReceipt(Uint8List receiptImage)`
Now includes:
- Proper initialization
- Image formatting with ESC/POS
- Line feeds before cut
- Paper cut command

#### `printText(String text)`
Now uses `printTextFormatted()` internally for proper ESC/POS encoding

#### `printNewLine()`
Now sends proper ESC/POS feed commands instead of simple newlines

## ESC/POS Command Breakdown

### Essential Commands Used:

| Command | Effect |
|---------|--------|
| `ESC @` | Initialize/reset printer |
| `ESC d n` | Feed n lines |
| `GS V m` | Cut paper |
| `ESC p` | Control buzzer/LED |
| `ESC t` | Set character code page |

### What Each Step Does:

1. **`generator.reset()`** 
   - Sends ESC @ command
   - Clears printer memory
   - Resets to default state
   - **Critical for consistent printing**

2. **`generator.text()` / `generator.image()`**
   - Formats content with proper encoding
   - Handles text wrapping for paper width
   - Applies text styles (bold, size, alignment)

3. **`generator.feed(n)`**
   - Advance paper by n lines
   - Gives space for clean cut
   - Prevents cutting on printed content

4. **`generator.cut()`**
   - Sends GS V command
   - Cuts paper after printing
   - Only works if printer has auto-cutter

## Why Previous Attempts Didn't Work

1. **No Initialization** - Printer state was undefined
2. **Missing Termination** - No cut command sent
3. **Incomplete Protocol** - Basic wrapper didn't include all ESC/POS codes
4. **Buffer Issues** - Data not properly flushed/terminated

## Now Try This

After connecting to your printer:

```dart
// Step 1: Connect
bool connected = await printerService.connect(selectedDevice);
if (!connected) {
  print('Failed to connect');
  return;
}

// Step 2: Initialize printer (important!)
bool initialized = await printerService.initializePrinter();
if (!initialized) {
  print('Failed to initialize printer');
  return;
}

// Step 3: Print receipt (now with proper ESC/POS)
bool printed = await printerService.printReceipt(receiptImageBytes);
if (printed) {
  print('Receipt printed successfully!');
} else {
  print('Printing failed');
}
```

## Testing Steps

1. **Connect to paired printer** ✓ (you already did this)
2. **Call `initializePrinter()`** 
   - Watch debug logs: "Initializing printer with ESC/POS commands..."
   - Should see: "Printer initialization successful"
3. **Print test text**
   ```dart
   await printerService.printTextFormatted("TEST");
   ```
4. **Print receipt image**
   ```dart
   await printerService.printReceipt(receiptImageBytes);
   ```

## Debug Output to Watch

```
I/PrinterService: Initializing printer with ESC/POS commands...
I/PrinterService: Printer initialization successful
I/PrinterService: Starting receipt print with image size: 123456 bytes
I/PrinterService: Receipt formatted to 456789 ESC/POS bytes
I/PrinterService: Sending 456789 bytes to printer...
I/PrinterService: Data sent successfully
```

## If It Still Doesn't Print

Even with proper ESC/POS format, some printers might need:

1. **Different paper width** - Try `PaperSize.mm80` instead of `mm58`
   ```dart
   final generator = Generator(PaperSize.mm80);  // 80mm thermal printer
   ```

2. **Additional delays** - Some cheap printers need time between commands
   ```dart
   await printerService.sendRawData(bytes);
   await Future.delayed(Duration(milliseconds: 100));
   ```

3. **Different code page** - For special characters:
   ```dart
   bytes.addAll(generator.setGlobalCodePage(CodePage.cpWithKozantaji));
   ```

4. **Manual test with raw bytes**
   ```dart
   // Send absolute minimal ESC/POS
   final minimalTest = [27, 64];  // ESC @
   await printerService.sendRawData(minimalTest);
   ```

## File Modified

- `lib/data/services/printer_service.dart`
  - Added `import 'package:esc_pos_utils/esc_pos_utils.dart'`
  - Added `initializePrinter()` method
  - Added `sendRawData()` method
  - Added `printTextFormatted()` method
  - Updated `printReceipt()` to use proper ESC/POS
  - Updated `printText()` and `printNewLine()` to use proper formatting
