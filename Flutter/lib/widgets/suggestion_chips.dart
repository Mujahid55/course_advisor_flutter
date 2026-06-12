import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SuggestionChips extends StatelessWidget {
  final bool syllabusUploaded;
  final Function(String) onSuggestionTap;

  static const List<String> _afterUpload = [
    '📚 Recommend textbooks',
    '🎯 What are the key topics?',
    '📝 Summarize the syllabus',
    '📅 What should I focus on for exams?',
  ];

  static const List<String> _beforeUpload = [
    '📎 How do I upload my syllabus?',
    '❓ What can you help me with?',
    '📖 What is CourseAdvisor?',
  ];

  const SuggestionChips({
    super.key,
    required this.syllabusUploaded,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = syllabusUploaded ? _afterUpload : _beforeUpload;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => onSuggestionTap(suggestions[index]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              suggestions[index],
              style: GoogleFonts.inter(
                color: const Color(0xFF475569),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
