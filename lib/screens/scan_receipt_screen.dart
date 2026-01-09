import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../shell/app_shell.dart';
import '../services/expense_service.dart';
import '../models/expense.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> with TickerProviderStateMixin {
  final ExpenseService _expenseService = ExpenseService();
  CameraController? _controller;
  bool _isCameraReady = false;
  bool _isSimOrNoCamera = false;

  bool isScanning = false;
  bool isProcessing = false;
  bool isComplete = false;

  late final AnimationController _scanLineController;
  late final AnimationController _scaleInController;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _scaleInController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _expenseService.debugListAvailableModels();

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _isSimOrNoCamera = true);
        return;
      }

      // Prefer back camera
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _isCameraReady = true;
      });
    } catch (_) {
      // iOS Simulator often ends here (no camera)
      if (!mounted) return;
      setState(() => _isSimOrNoCamera = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scanLineController.dispose();
    _scaleInController.dispose();
    super.dispose();
  }

  Future<void> _handleCapture() async {
    if (isScanning) return;

    setState(() {
      isScanning = true;
      isProcessing = true;
      isComplete = false;
    });

    try {
      // Capture the actual image from the camera
      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.setFlashMode(FlashMode.off);
        
        // This takes the actual photo
        final XFile photo = await _controller!.takePicture();
        
        // Convert the photo file into bytes that Gemini can understand
        final bytes = await photo.readAsBytes();

        // Send the bytes to your ExpenseService
        // This will talk to Gemini and save to your backend
        final expense = await _expenseService.processReceipt(bytes); // comment out if you dont want to spend tokens in testing

        // // MOCK DATA: Pretend the AI worked
        // final expense = Expense(
        //   merchant: "Test Shop", 
        //   amount: 10.0, 
        //   category: "Groceries", 
        //   date: DateTime.now()
        // );

        if (expense != null) {
          print("Successfully identified: ${expense.merchant} - ${expense.amount}");

          if (mounted) {
            _showConfirmationSheet(context, expense);
          }
        }
      } else if (_isSimOrNoCamera) {
        // Fallback for testing UI in the simulator without a camera
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      print("Error during capture or AI processing: $e");
      // Show an error message to the user
    }

    if (!mounted) return;

    // Trigger the "Success" animations
    setState(() {
      isProcessing = false;
      isComplete = true;
    });
    _scaleInController.forward(from: 0);

    // Reset the UI back to camera mode after 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() {
      isScanning = false;
      isComplete = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Camera preview or fallback background
            Positioned.fill(
              child: _buildCameraOrFallback(),
            ),

            // Header gradient + controls
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _TopHeader(
                onClose: () => Navigator.of(context).maybePop(),
                onGallery: () {
                  // TODO: implement picking from gallery later
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Gallery picker not wired yet.")),
                  );
                },
              ),
            ),

            // Scanning frame (center)
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: _ScanningFrame(
                      isScanning: isScanning && !isComplete,
                      isProcessing: isProcessing && !isComplete,
                      isComplete: isComplete,
                      scanLine: _scanLineController,
                      scaleIn: _scaleInController,
                    ),
                  ),
                ),
              ),
            ),

            // Instructions (only when not scanning)
            if (!isScanning)
              Positioned(
                left: 20,
                right: 20,
                top: MediaQuery.of(context).size.height * 0.60,
                child: _InstructionChip(
                  text: _isSimOrNoCamera
                      ? "No camera available (simulator). Try on a real phone."
                      : "Position receipt within the frame",
                ),
              ),

            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomControls(
                isDisabled: isScanning,
                onCapture: _handleCapture,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraOrFallback() {
    if (_isCameraReady && _controller != null) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize?.height ?? 0,
          height: _controller!.value.previewSize?.width ?? 0,
          child: CameraPreview(_controller!),
        ),
      );
    }

    // Fallback background (matches your simulated gradient vibe)
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2937), Color(0xFF374151), Color(0xFF111827)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.10,
              child: Row(
                children: const [
                  Expanded(child: _VBorder()),
                  Expanded(child: _VBorder()),
                  Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmationSheet(BuildContext context, Expense expense) {
  // Controllers to allow editing if the AI made a tiny mistake
  final merchantController = TextEditingController(text: expense.merchant);
  final amountController = TextEditingController(text: expense.amount.toString());
  String selectedCategory = expense.category;

  final List<String> categories = [
    'Rent', 'Utilities', 'Entertainment', 'Groceries',
    'Transportation', 'Savings', 'Healthcare', 'Other'
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: EdgeInsets.only(
        top: 20, left: 20, right: 20, 
        bottom: MediaQuery.of(context).viewInsets.bottom + 20
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937), // Matches your dark theme
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Verify Expense", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          // Merchant Field
          TextField(
            controller: merchantController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Merchant"),
          ),
          const SizedBox(height: 15),

          // Amount Field
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Amount (€)"),
          ),
          const SizedBox(height: 15),

          // Category Dropdown
          DropdownButtonFormField<String>(
            value: categories.contains(selectedCategory) ? selectedCategory : 'Other',
            dropdownColor: const Color(0xFF374151),
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Category"),
            items: categories.map((cat) => DropdownMenuItem(
              value: cat, 
              child: Text(cat)
            )).toList(),
            onChanged: (val) => selectedCategory = val!,
          ),
          const SizedBox(height: 25),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final merchant = merchantController.text;
                final amount = double.tryParse(amountController.text) ?? 0.0;
                final category = selectedCategory.toLowerCase(); // Django expects lowercase "groceries"

                try {
                  // We send this to our backend service
                  await _expenseService.saveToDatabase(
                    merchant: merchant,
                    amount: amount,
                    category: category,
                  );

                  if (mounted) {
                    Navigator.pop(context); // Close sheet
                    Navigator.pushReplacementNamed(context, '/budget');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Added €$amount to $selectedCategory"))
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error saving: $e"))
                  );
                }
              },
              child: const Text("Confirm & Save", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    ),
  );
}

// Helper for styling the inputs
InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.grey),
    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(10)),
    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF3B82F6)), borderRadius: BorderRadius.circular(10)),
  );
}
}

class _VBorder extends StatelessWidget {
  const _VBorder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white)),
      ),
    );
  }
}

/// ----------------------------
/// UI Pieces (header / frame / bottom)
/// ----------------------------
class _TopHeader extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onGallery;

  const _TopHeader({required this.onClose, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 52, 18, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GlassIconButton(icon: Icons.close_rounded, onTap: onClose),
          const Text(
            "Scan Receipt",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          _GlassIconButton(icon: Icons.image_outlined, onTap: onGallery),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

class _ScanningFrame extends StatelessWidget {
  final bool isScanning;
  final bool isProcessing;
  final bool isComplete;
  final AnimationController scanLine;
  final AnimationController scaleIn;

  const _ScanningFrame({
    required this.isScanning,
    required this.isProcessing,
    required this.isComplete,
    required this.scanLine,
    required this.scaleIn,
  });

  @override
  Widget build(BuildContext context) {
    // 3:4 frame like your aspect-[3/4]
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: LayoutBuilder(
        builder: (context, c) {
          final frameH = c.maxHeight;

          return Stack(
            children: [
              // Corner brackets
              _CornerBrackets(),

              // Scan line
              if (isScanning)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedBuilder(
                    animation: scanLine,
                    builder: (context, _) {
                      final y = (scanLine.value * frameH).clamp(0.0, frameH);
                      return Stack(
                        children: [
                          Positioned(
                            top: y,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 4,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Color(0xFF3B82F6), Colors.transparent],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              // Processing overlay
              if (isProcessing)
                _Overlay(
                  tint: const Color(0xFF3B82F6).withOpacity(0.20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                          backgroundColor: Color(0x55FFFFFF),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text("Processing receipt...", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),

              // Success overlay
              if (isComplete)
                _Overlay(
                  tint: const Color(0xFF22C55E).withOpacity(0.20),
                  child: ScaleTransition(
                    scale: CurvedAnimation(parent: scaleIn, curve: Curves.easeOutBack),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 82),
                        SizedBox(height: 12),
                        Text("Receipt captured!", style: TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  final Color tint;
  final Widget child;

  const _Overlay({required this.tint, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: tint,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

class _CornerBrackets extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF3B82F6);
    const w = 48.0;
    const t = 4.0;
    const r = 18.0;

    Widget corner({
      required Alignment align,
      required bool top,
      required bool left,
      required bool right,
      required bool bottom,
    }) {
      return Align(
        alignment: align,
        child: Container(
          width: w,
          height: w,
          decoration: BoxDecoration(
            // borderRadius: BorderRadius.only(
            //   topLeft: Radius.circular(top && left ? r : 0),
            //   topRight: Radius.circular(top && right ? r : 0),
            //   bottomLeft: Radius.circular(bottom && left ? r : 0),
            //   bottomRight: Radius.circular(bottom && right ? r : 0),
            // ),
            border: Border(
              top: BorderSide(color: top ? c : Colors.transparent, width: t),
              left: BorderSide(color: left ? c : Colors.transparent, width: t),
              right: BorderSide(color: right ? c : Colors.transparent, width: t),
              bottom: BorderSide(color: bottom ? c : Colors.transparent, width: t),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        corner(align: Alignment.topLeft, top: true, left: true, right: false, bottom: false),
        corner(align: Alignment.topRight, top: true, left: false, right: true, bottom: false),
        corner(align: Alignment.bottomLeft, top: false, left: true, right: false, bottom: true),
        corner(align: Alignment.bottomRight, top: false, left: false, right: true, bottom: true),
      ],
    );
  }
}

class _InstructionChip extends StatelessWidget {
  final String text;
  const _InstructionChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.50),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  final bool isDisabled;
  final VoidCallback onCapture;

  const _BottomControls({required this.isDisabled, required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tips row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Tip(icon: Icons.bolt_rounded, text: "Auto-capture"),
                const SizedBox(width: 18),
                _Tip(icon: Icons.photo_camera_rounded, text: "HD Quality"),
              ],
            ),
            const SizedBox(height: 18),

            // Capture button
            GestureDetector(
              onTap: isDisabled ? null : onCapture,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: isDisabled ? 0.5 : 1.0,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.30), width: 4),
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        ),
                      ),
                      child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),
            Text(
              "Tap to capture or hold still for auto-scan",
              style: TextStyle(color: Colors.white.withOpacity(0.55)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.70), size: 18),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: Colors.white.withOpacity(0.70))),
      ],
    );
  }
}
