import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class PdfGenerator {
  static Future<File> generateAnswersPdf({
    required String subject,
    required String year,
    required String category,
    required String aiContent,
  }) async {
    final pdf = pw.Document();

    // Create a multi-page document with proper page breaks
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: 100, // Allow up to 100 pages for very long content
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Text('AI Generated Answers',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),

          // Subject info
          pw.Header(
            level: 1,
            child: pw.Text('$subject - $year ($category)',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),

          pw.SizedBox(height: 12),

          // Content - wrapped in a Column with crossAxisAlignment to handle flow
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('AI-Generated Answers:',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              // Split the content into paragraphs to help with pagination
              ...aiContent
                  .split('\n\n')
                  .map((paragraph) => pw.Padding(
                        padding: pw.EdgeInsets.only(bottom: 8),
                        child: pw.Text(paragraph,
                            style: pw.TextStyle(fontSize: 12)),
                      ))
                  .toList(),
            ],
          ),

          // Footer with disclaimer
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Text(
            'Disclaimer: These answers are AI-generated and should be used as a study aid only. Verify information independently for academic purposes.',
            style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
          ),
        ],
        footer: (context) => pw.Padding(
          padding: pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated with MyEducation App',
                  style: pw.TextStyle(fontSize: 8)),
              pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8)),
            ],
          ),
        ),
      ),
    );

    // Save PDF to file
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'ai_answers_${subject.replaceAll(' ', '_')}_$year.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
