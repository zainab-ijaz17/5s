import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class QuestionCard extends StatefulWidget {
  final String question;
  final String questionDetails; // Added question details for info popup
  final String category; // 5S category (SORT, SET, SHINE, STANDARDIZE, SUSTAIN)
  final Function(String) onAnswer;
  final Function(List<File>)? onImagesSelected;
  final Function(String)? onCommentChanged;
  final String? initialAnswer;
  final String? initialComment;
  final String? initialImagePath;

  const QuestionCard({
    super.key,
    required this.question,
    required this.questionDetails, // Question details for info popup
    required this.category, // 5S category
    required this.onAnswer,
    this.onImagesSelected,
    this.onCommentChanged,
    this.initialAnswer,
    this.initialComment,
    this.initialImagePath,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  String? selectedAnswer;
  List<File> selectedImages = [];
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    selectedAnswer = widget.initialAnswer;
    if (widget.initialComment != null) {
      _commentController.text = widget.initialComment!;
    }
    // Handle multiple initial images if any
    if (widget.initialImagePath != null &&
        widget.initialImagePath!.isNotEmpty) {
      // For backward compatibility, handle single image path
      selectedImages = [File(widget.initialImagePath!)];
    }
  }

  @override
  // Helper method to build category info section
  List<Widget> _buildCategoryInfo(String title, String content, Color color) {
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool isFlagged = selectedAnswer == 'No' || selectedAnswer == 'N/A';

    // Define colors for each 5S category
    final categoryColors = {
      'SORT': const Color(0xFF3B82F6), // Blue
      'SET': const Color(0xFF10B981), // Green
      'SHINE': const Color(0xFFF59E0B), // Amber
      'STANDARDIZE': const Color(0xFF8B5CF6), // Purple
      'SUSTAIN': const Color(0xFFEC4899), // Pink
    };

    final categoryColor =
        categoryColors[widget.category] ?? const Color(0xFF0891B2);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isFlagged
            ? const BorderSide(color: Color(0xFFEF4444), width: 2)
            : BorderSide(color: categoryColor.withOpacity(0.2)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isFlagged
              ? const Color(0xFFEF4444).withOpacity(0.05)
              : Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: categoryColor.withOpacity(0.3)),
                ),
                child: Text(
                  widget.category,
                  style: TextStyle(
                    color: categoryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Question and info icon
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isFlagged
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF0F172A),
                        height: 1.4,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showQuestionDetails(context),
                    icon: Icon(
                      Icons.help_outline_rounded,
                      color: categoryColor,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'View 5S Details',
                  ),
                ],
              ),

              if (isFlagged) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag, color: Color(0xFFEF4444), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'FLAGGED - Requires Attention',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAnswerButton(
                      'Yes', Icons.check_circle, const Color(0xFF10B981)),
                  _buildAnswerButton(
                      'No', Icons.cancel, const Color(0xFFEF4444)),
                  _buildAnswerButton(
                      'N/A', Icons.help_outline, const Color(0xFF6B7280)),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 16),

              if (isFlagged) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0891B2),
                          side: const BorderSide(color: Color(0xFF0891B2)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt, size: 20),
                        label: Text(
                          selectedImages.isNotEmpty
                              ? 'Add More Photos'
                              : 'Add Photo',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                if (selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Attached Photos:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: selectedImages.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      selectedImages[index],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedImages.removeAt(index);
                                        });
                                        _notifyImageChange();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],

              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: isFlagged
                      ? 'Remarks (Required)'
                      : 'Comments (Optional)', // Required remarks for flagged questions
                  labelStyle: TextStyle(
                      color: isFlagged
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF6B7280)),
                  hintText: isFlagged
                      ? 'Please provide remarks for this flagged item...'
                      : 'Add any additional observations or notes...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: isFlagged
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFD1D5DB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: isFlagged
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF0891B2),
                        width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                onChanged: (value) {
                  if (widget.onCommentChanged != null) {
                    widget.onCommentChanged!(value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuestionDetails(BuildContext context) {
    // Define colors for each 5S category
    final categoryColors = {
      'SORT': const Color(0xFF3B82F6), // Blue
      'SET': const Color(0xFF10B981), // Green
      'SHINE': const Color(0xFFF59E0B), // Amber
      'STANDARDIZE': const Color(0xFF8B5CF6), // Purple
      'SUSTAIN': const Color(0xFFEC4899), // Pink
    };

    final categoryColor =
        categoryColors[widget.category] ?? const Color(0xFF0891B2);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.info_outline,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.category} - 5S Category',
                        style: TextStyle(
                          color: categoryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Question Details',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  widget.question,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GUIDANCE',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.questionDetails,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.category == 'SORT')
                  ..._buildCategoryInfo(
                    'SORT - Eliminate what is not needed',
                    '• Remove all unnecessary items from the workplace\n• Keep only essential items for current operations\n• Implement red tagging for unneeded items',
                    categoryColor,
                  ),
                if (widget.category == 'SET')
                  ..._buildCategoryInfo(
                    'SET - Organize what remains',
                    '• Arrange items for easy access and use\n• Use labels, floor markings, and color coding\n• Implement shadow boards and tool outlines',
                    categoryColor,
                  ),
                if (widget.category == 'SHINE')
                  ..._buildCategoryInfo(
                    'SHINE - Clean the workplace',
                    '• Keep the workplace clean and inspect equipment\n• Identify and eliminate sources of contamination\n• Make cleaning and inspection a part of daily work',
                    categoryColor,
                  ),
                if (widget.category == 'STANDARDIZE')
                  ..._buildCategoryInfo(
                    'STANDARDIZE - Make it consistent',
                    '• Develop standards for the first three S\'s\n• Create procedures and schedules\n• Use visual controls to make problems obvious',
                    categoryColor,
                  ),
                if (widget.category == 'SUSTAIN')
                  ..._buildCategoryInfo(
                    'SUSTAIN - Maintain the standards',
                    '• Make 5S a daily habit\n• Conduct regular audits and training\n• Recognize and reward good practices',
                    categoryColor,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
              ),
              child: const Text('Close',
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        );
      },
    );
  }

  void _showRemarksDialog(String answer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final TextEditingController remarksController = TextEditingController();
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text(
                'Remarks Required',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You selected "$answer" for this question. Please provide remarks explaining the issue.',
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: remarksController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Remarks',
                  hintText:
                      'Describe the issue and any corrective actions needed...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFFEF4444), width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (remarksController.text.trim().isNotEmpty) {
                  _commentController.text = remarksController.text;
                  if (widget.onCommentChanged != null) {
                    widget.onCommentChanged!(remarksController.text);
                  }
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide remarks before continuing'),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
              ),
              child: const Text('Save Remarks'),
            ),
          ],
        );
      },
    );
  }

  void _notifyImageChange() {
    if (widget.onImagesSelected != null) {
      widget.onImagesSelected!(selectedImages);
    }
  }

  Future<void> _pickImage() async {
    try {
      // Show choice dialog between camera and gallery
      final source = await _showImageSourceDialog();
      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        // Validate image format
        bool isValid = false;
        
        // For web/URL-based images, check mimeType if available
        if (image.path.startsWith('blob:')) {
          final mimeType = image.mimeType?.toLowerCase();
          print('DEBUG: Image mimeType: "$mimeType"');
          isValid = mimeType == 'image/jpeg' || mimeType == 'image/jpg' || mimeType == 'image/png';
        } else {
          // For local files, check file extension
          final extension = image.path.split('.').last.toLowerCase();
          print('DEBUG: Image path: ${image.path}');
          print('DEBUG: Detected extension: "$extension"');
          const allowedExtensions = {'jpg', 'jpeg', 'png'};
          isValid = allowedExtensions.contains(extension);
        }
        
        if (!isValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Invalid image format. Only JPG, JPEG, and PNG are allowed.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
          return;
        }

        setState(() {
          selectedImages.add(File(image.path));
        });

        _notifyImageChange();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF0891B2)),
                title: const Text('Take Photo'),
                subtitle: const Text('Use camera to take a new picture'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: Color(0xFF0891B2)),
                title: const Text('Choose from Gallery'),
                subtitle:
                    const Text('Select an existing image from your device'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnswerButton(String answer, IconData icon, Color color) {
    final isSelected = selectedAnswer == answer;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: () {
            setState(() {
              selectedAnswer = answer;
            });
            widget.onAnswer(answer);

            if (answer == 'No' || answer == 'N/A') {
              Future.delayed(const Duration(milliseconds: 100), () {
                _showRemarksDialog(answer);
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? color : Colors.white,
            foregroundColor: isSelected ? Colors.white : color,
            side: BorderSide(color: color, width: 2),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: isSelected ? 4 : 1,
          ),
          icon: Icon(icon, size: 18),
          label: Text(
            answer,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
