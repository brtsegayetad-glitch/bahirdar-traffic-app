import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

Future<void> savePdf(Uint8List bytes, String fileName) async {
  await Printing.layoutPdf(onLayout: (PdfPageFormat format) => bytes);
}
