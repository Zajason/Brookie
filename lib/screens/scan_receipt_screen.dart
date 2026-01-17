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
    _scanLineController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _scaleInController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _isSimOrNoCamera = true);
        return;
      }
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      
      final controller = CameraController(
        back,
        ResolutionPreset.medium, // CRITICAL: 'medium' prevents ANR crash
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
      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.setFlashMode(FlashMode.off);
        final XFile photo = await _controller!.takePicture();
        final bytes = await photo.readAsBytes();

        final expense = await _expenseService.processReceipt(bytes);

        if (expense != null && mounted) {
           _showConfirmationSheet(context, expense);
        }
      } else if (_isSimOrNoCamera) {
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      print("Error: $e");
    }

    if (!mounted) return;
    setState(() {
      isProcessing = false;
      isComplete = true;
    });
    _scaleInController.forward(from: 0);

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      isScanning = false;
      isComplete = false;
    });
  }

  void _showConfirmationSheet(BuildContext context, Expense expense) {
    final merchantController = TextEditingController(text: expense.merchant);
    final amountController = TextEditingController(text: expense.amount.toString());
    
    String selectedCategory = expense.category;
    DateTime selectedDate = expense.date; 

    final List<String> categories = [
      'Rent', 'Utilities', 'Entertainment', 'Groceries',
      'Transportation', 'Savings', 'Healthcare', 'Other'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20, 
                bottom: MediaQuery.of(context).viewInsets.bottom + 20
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1F2937),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Verify Expense", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: merchantController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Merchant"),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Amount (€)"),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: categories.any((c) => c.toLowerCase() == selectedCategory.toLowerCase()) 
                        ? categories.firstWhere((c) => c.toLowerCase() == selectedCategory.toLowerCase()) 
                        : 'Other',
                    dropdownColor: const Color(0xFF374151),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration("Category"),
                    items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                    onChanged: (val) {
                      setModalState(() => selectedCategory = val!);
                    },
                  ),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFF3B82F6),
                                onPrimary: Colors.white,
                                surface: Color(0xFF1F2937),
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null && picked != selectedDate) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Date: ${selectedDate.toIso8601String().split('T')[0]}",
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text) ?? 0.0;
                        final category = selectedCategory.toLowerCase();
                        final dateStr = selectedDate.toIso8601String().split('T')[0];

                        try {
                          await _expenseService.saveToDatabase(
                            amount: amount,
                            category: category,
                            date: dateStr,
                          );

                          if (mounted) {
                            Navigator.pop(context);
                            Navigator.pushReplacementNamed(context, '/budget');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Added €$amount to $selectedCategory"))
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: $e"))
                          );
                        }
                      },
                      child: const Text("Confirm & Save", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF3B82F6)), borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: _buildCameraOrFallback()),
            Positioned(
              left: 0, right: 0, top: 0,
              child: _TopHeader(onClose: () => Navigator.of(context).maybePop(), onGallery: () {}),
            ),
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
            if (!isScanning)
              Positioned(
                left: 20, right: 20,
                top: MediaQuery.of(context).size.height * 0.60,
                child: _InstructionChip(text: _isSimOrNoCamera ? "No camera (Simulator)." : "Position receipt within the frame"),
              ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _BottomControls(isDisabled: isScanning, onCapture: _handleCapture),
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
    return Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1F2937), Color(0xFF374151), Color(0xFF111827)])));
  }
}

// ... COPY YOUR WIDGETS HERE (_VBorder, _ScanningFrame, etc) ...
// (I omitted the smaller widget classes to save space, but you have them from the previous file)
class _VBorder extends StatelessWidget { const _VBorder(); @override Widget build(BuildContext context) => Container(decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.white)))); }
class _TopHeader extends StatelessWidget { final VoidCallback onClose; final VoidCallback onGallery; const _TopHeader({required this.onClose, required this.onGallery}); @override Widget build(BuildContext context) { return Container(padding: const EdgeInsets.fromLTRB(56, 76, 18, 14), decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xCC000000), Color(0x00000000)])), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_GlassIconButton(icon: Icons.close_rounded, onTap: onClose), const Text("Scan Receipt", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)), _GlassIconButton(icon: Icons.image_outlined, onTap: onGallery)])); } }
class _GlassIconButton extends StatelessWidget { final IconData icon; final VoidCallback onTap; const _GlassIconButton({required this.icon, required this.onTap}); @override Widget build(BuildContext context) { return ClipRRect(borderRadius: BorderRadius.circular(999), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: InkWell(onTap: onTap, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withOpacity(0.20), borderRadius: BorderRadius.circular(999)), child: Icon(icon, color: Colors.white, size: 24))))); } }
class _ScanningFrame extends StatelessWidget { final bool isScanning, isProcessing, isComplete; final AnimationController scanLine, scaleIn; const _ScanningFrame({required this.isScanning, required this.isProcessing, required this.isComplete, required this.scanLine, required this.scaleIn}); @override Widget build(BuildContext context) { return AspectRatio(aspectRatio: 3 / 4, child: LayoutBuilder(builder: (context, c) { final frameH = c.maxHeight; return Stack(children: [_CornerBrackets(), if (isScanning) ClipRRect(borderRadius: BorderRadius.circular(18), child: AnimatedBuilder(animation: scanLine, builder: (context, _) { final y = (scanLine.value * frameH).clamp(0.0, frameH); return Positioned(top: y, left: 0, right: 0, child: Container(height: 4, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Color(0xFF3B82F6), Colors.transparent])))); })), if (isProcessing) _Overlay(tint: const Color(0xFF3B82F6).withOpacity(0.20), child: Column(mainAxisSize: MainAxisSize.min, children: const [SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 4, valueColor: AlwaysStoppedAnimation(Colors.white))), SizedBox(height: 16), Text("Processing...", style: TextStyle(color: Colors.white, fontSize: 16))])), if (isComplete) _Overlay(tint: const Color(0xFF22C55E).withOpacity(0.20), child: ScaleTransition(scale: CurvedAnimation(parent: scaleIn, curve: Curves.easeOutBack), child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 82), SizedBox(height: 12), Text("Captured!", style: TextStyle(color: Colors.white, fontSize: 16))]))),]); })); } }
class _Overlay extends StatelessWidget { final Color tint; final Widget child; const _Overlay({required this.tint, required this.child}); @override Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(18), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: tint, alignment: Alignment.center, child: child))); }
class _CornerBrackets extends StatelessWidget { @override Widget build(BuildContext context) { const c = Color(0xFF3B82F6); const w = 48.0; const t = 4.0; Widget corner(Alignment a, bool top, bool left) => Align(alignment: a, child: Container(width: w, height: w, decoration: BoxDecoration(border: Border(top: top ? BorderSide(color: c, width: t) : BorderSide.none, left: left ? BorderSide(color: c, width: t) : BorderSide.none, right: !left ? BorderSide(color: c, width: t) : BorderSide.none, bottom: !top ? BorderSide(color: c, width: t) : BorderSide.none)))); return Stack(children: [corner(Alignment.topLeft, true, true), corner(Alignment.topRight, true, false), corner(Alignment.bottomLeft, false, true), corner(Alignment.bottomRight, false, false)]); } }
class _InstructionChip extends StatelessWidget { final String text; const _InstructionChip({required this.text}); @override Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(18), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: Colors.black.withOpacity(0.50), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.10))), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))))); }
class _BottomControls extends StatelessWidget { final bool isDisabled; final VoidCallback onCapture; const _BottomControls({required this.isDisabled, required this.onCapture}); @override Widget build(BuildContext context) { return Container(padding: const EdgeInsets.fromLTRB(20, 16, 20, 26), decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xCC000000), Color(0x00000000)])), child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Row(children: [Icon(Icons.bolt_rounded, color: Colors.white70, size: 18), SizedBox(width: 6), Text("Auto", style: TextStyle(color: Colors.white70))]), SizedBox(width: 18), Row(children: [Icon(Icons.photo_camera_rounded, color: Colors.white70, size: 18), SizedBox(width: 6), Text("HD", style: TextStyle(color: Colors.white70))])]), const SizedBox(height: 18), GestureDetector(onTap: isDisabled ? null : onCapture, child: AnimatedOpacity(duration: const Duration(milliseconds: 150), opacity: isDisabled ? 0.5 : 1.0, child: Container(width: 84, height: 84, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.30), width: 4)), child: Center(child: Container(width: 64, height: 64, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)])), child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 30)))))), const SizedBox(height: 14), Text("Tap to capture", style: TextStyle(color: Colors.white.withOpacity(0.55))),]))); } }