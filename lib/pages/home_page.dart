import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? selectedMedia;
  String? recognizedText;
  bool isPdf = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Text Recognition",
        ),
      ),
      body: _buildUI(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'jpg', 'png'],
          );
          if (result != null) {
            var file = File(result.files.single.path!);
            setState(() {
              selectedMedia = file;
              isPdf = file.path.endsWith(".pdf");
              recognizedText = null;  // Reset recognized text when new media is selected
            });
          }
        },
        child: const Icon(
          Icons.file_copy,
        ),
      ),
    );
  }

  Widget _buildUI() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _imageView()),
        Expanded(child: _extractTextView()),
      ],
    );
  }

  Widget _imageView() {
    if (selectedMedia == null) {
      return const Center(
        child: Text("Pick an image or PDF for text recognition."),
      );
    }

    if (isPdf) {
      return const Center(
        child: Text("PDF file selected."),
      );
    }

    return Center(
      child: Image.file(
        selectedMedia!,
        width: 200,
      ),
    );
  }

  Widget _extractTextView() {
    if (selectedMedia == null) {
      return const Center(
        child: Text("No file selected."),
      );
    }

    return FutureBuilder(
      future: isPdf ? _extractTextFromPdf(selectedMedia!) : _extractText(selectedMedia!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text("Error: ${snapshot.error}"),
          );
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Text(
              snapshot.data ?? "No text found.",
              style: const TextStyle(fontSize: 14),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _extractText(File file) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final InputImage inputImage = InputImage.fromFile(file);
    final RecognizedText recognizedText =
    await textRecognizer.processImage(inputImage);
    String text = recognizedText.text;
    textRecognizer.close();
    return text;
  }

  Future<String?> _extractTextFromPdf(File pdfFile) async {
    final document = await PdfDocument.openFile(pdfFile.path);
    final pageCount = document.pagesCount;
    String allText = '';

    for (int i = 1; i <= pageCount; i++) {
      final page = await document.getPage(i);
      final pageImage = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.png,
      );
      final imageFile = File('${pdfFile.path}_page_$i.png');
      await imageFile.writeAsBytes(pageImage!.bytes);

      // Recognize text from the image
      final text = await _extractText(imageFile);
      if (text != null) {
        allText += text + '\n';
      }

      await page.close();
    }

    await document.close();
    return allText;
  }
}
