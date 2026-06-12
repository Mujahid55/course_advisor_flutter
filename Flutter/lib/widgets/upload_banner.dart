import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UploadBanner extends StatelessWidget {
  final bool isUploaded;
  final bool isUploading;
  final String? fileName;
  final VoidCallback onTap;

  const UploadBanner({
    super.key,
    required this.isUploaded,
    required this.isUploading,
    this.fileName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isUploaded ? const Color(0xFF059669) : const Color(0xFF4F46E5);
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isUploaded
                ? [const Color(0xFF059669), const Color(0xFF10B981)]
                : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: isUploading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Icon(
                        isUploaded
                            ? Icons.check_circle_rounded
                            : Icons.upload_file_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUploaded
                        ? 'Syllabus Uploaded ✓'
                        : isUploading
                            ? 'Analyzing Syllabus...'
                            : 'Upload Your Syllabus',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isUploaded
                        ? fileName ?? 'Ready to answer your questions'
                        : isUploading
                            ? 'Please wait...'
                            : 'Tap to upload a PDF of your course syllabus',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isUploading)
              Icon(
                isUploaded
                    ? Icons.refresh_rounded
                    : Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.8),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
