import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/app_exception.dart';

class QuestionOcrReader {
  const QuestionOcrReader({
    this.minimumTextLength = 200,
    this.minimumQuestionHeadings = 1,
  });

  final int minimumTextLength;
  final int minimumQuestionHeadings;

  Future<String> read(File imageFile) async {
    final outputDirectory = Directory.systemTemp.createTempSync(
      'lecturer_grading_ocr_',
    );
    final processedImage = File(
      p.join(outputDirectory.path, 'question_alpha_ocr.png'),
    );
    final scriptFile = File(p.join(outputDirectory.path, 'question_ocr.ps1'))
      ..writeAsStringSync(_windowsOcrScript);

    try {
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptFile.path,
        imageFile.path,
        processedImage.path,
      ]);

      if (result.exitCode != 0) {
        throw AppException(
          'OCR failed for ${p.basename(imageFile.path)}: ${result.stderr}',
        );
      }

      final decoded = jsonDecode(result.stdout.toString());
      if (decoded is! Map<String, dynamic>) {
        throw const AppException('OCR did not return a JSON object.');
      }

      final text = (decoded['text'] as String? ?? '').trim();
      final lineCount = decoded['lineCount'] as int? ?? 0;
      _validateText(
        text: text,
        lineCount: lineCount,
        imageName: p.basename(imageFile.path),
      );
      return text;
    } on ProcessException catch (error) {
      throw AppException(
        'Windows PowerShell is required to run local OCR. Details: ${error.message}',
      );
    } on FormatException catch (error) {
      throw AppException('OCR returned invalid JSON. Details: $error');
    } finally {
      try {
        outputDirectory.deleteSync(recursive: true);
      } on FileSystemException {
        // Temporary OCR files are best-effort cleanup only.
      }
    }
  }

  void _validateText({
    required String text,
    required int lineCount,
    required String imageName,
  }) {
    final questionHeadings = RegExp(
      r'\b(?:request|question|requirement)\s*\d+\b',
      caseSensitive: false,
    ).allMatches(text).length;

    if (text.length < minimumTextLength ||
        lineCount < 3 ||
        questionHeadings < minimumQuestionHeadings) {
      throw AppException(
        'OCR text from $imageName is not reliable enough for AI grading. '
        'Detected ${text.length} characters, $lineCount lines, and '
        '$questionHeadings question heading(s).',
      );
    }
  }
}

const _windowsOcrScript = r'''
param(
  [Parameter(Mandatory=$true)][string]$InputImage,
  [Parameter(Mandatory=$true)][string]$ProcessedImage
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
$preprocessCode = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class AlphaQuestionOcrPreprocessor {
  public static void Save(string input, string output, int alphaThreshold, int scale) {
    using (var src = new Bitmap(input)) {
      int width = src.Width;
      int height = src.Height;
      var rect = new Rectangle(0, 0, width, height);
      var srcData = src.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
      int bytes = Math.Abs(srcData.Stride) * height;
      byte[] srcBytes = new byte[bytes];
      Marshal.Copy(srcData.Scan0, srcBytes, 0, bytes);
      src.UnlockBits(srcData);

      int minX = width;
      int minY = height;
      int maxX = 0;
      int maxY = 0;
      bool[,] ink = new bool[width, height];

      for (int y = 0; y < height; y++) {
        int row = y * srcData.Stride;
        for (int x = 0; x < width; x++) {
          int index = row + x * 4;
          bool isInk = srcBytes[index + 3] > alphaThreshold;
          ink[x, y] = isInk;
          if (isInk) {
            if (x < minX) minX = x;
            if (y < minY) minY = y;
            if (x > maxX) maxX = x;
            if (y > maxY) maxY = y;
          }
        }
      }

      if (minX > maxX || minY > maxY) {
        throw new InvalidOperationException("Image has no visible text pixels.");
      }

      int padding = 40;
      minX = Math.Max(0, minX - padding);
      minY = Math.Max(0, minY - padding);
      maxX = Math.Min(width - 1, maxX + padding);
      maxY = Math.Min(height - 1, maxY + padding);

      int croppedWidth = maxX - minX + 1;
      int croppedHeight = maxY - minY + 1;
      using (var cropped = new Bitmap(croppedWidth, croppedHeight, PixelFormat.Format32bppArgb)) {
        using (var graphics = Graphics.FromImage(cropped)) {
          graphics.Clear(Color.White);
        }

        var outRect = new Rectangle(0, 0, croppedWidth, croppedHeight);
        var outData = cropped.LockBits(outRect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        int outBytes = Math.Abs(outData.Stride) * croppedHeight;
        byte[] outPixels = new byte[outBytes];
        for (int i = 0; i < outBytes; i += 4) {
          outPixels[i] = 255;
          outPixels[i + 1] = 255;
          outPixels[i + 2] = 255;
          outPixels[i + 3] = 255;
        }

        for (int y = 0; y < croppedHeight; y++) {
          for (int x = 0; x < croppedWidth; x++) {
            if (!ink[x + minX, y + minY]) continue;
            int index = y * outData.Stride + x * 4;
            outPixels[index] = 0;
            outPixels[index + 1] = 0;
            outPixels[index + 2] = 0;
            outPixels[index + 3] = 255;
          }
        }

        Marshal.Copy(outPixels, 0, outData.Scan0, outBytes);
        cropped.UnlockBits(outData);

        using (var scaled = new Bitmap(croppedWidth * scale, croppedHeight * scale, PixelFormat.Format32bppArgb)) {
          using (var graphics = Graphics.FromImage(scaled)) {
            graphics.Clear(Color.White);
            graphics.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
            graphics.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half;
            graphics.DrawImage(cropped, new Rectangle(0, 0, scaled.Width, scaled.Height));
          }
          scaled.Save(output, ImageFormat.Png);
        }
      }
    }
  }
}
'@
Add-Type -TypeDefinition $preprocessCode -ReferencedAssemblies System.Drawing
[AlphaQuestionOcrPreprocessor]::Save($InputImage, $ProcessedImage, 0, 2)

Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
[Windows.Storage.Streams.IRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.SoftwareBitmap,Windows.Graphics.Imaging,ContentType=WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime] | Out-Null
[Windows.Globalization.Language,Windows.Globalization,ContentType=WindowsRuntime] | Out-Null

function AwaitOp($operation, [Type]$resultType) {
  $method = [System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object {
      $_.Name -eq 'AsTask' -and
      $_.IsGenericMethod -and
      $_.GetParameters().Count -eq 1
    } |
    Select-Object -First 1
  $task = $method.MakeGenericMethod($resultType).Invoke($null, @($operation))
  $task.Wait()
  $task.Result
}

$file = AwaitOp ([Windows.Storage.StorageFile]::GetFileFromPathAsync($ProcessedImage)) ([Windows.Storage.StorageFile])
$stream = AwaitOp ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
$decoder = AwaitOp ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
$bitmap = AwaitOp ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new('en-US'))
$result = AwaitOp ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])

$lines = @()
foreach ($line in $result.Lines) {
  $words = @()
  foreach ($word in $line.Words) {
    $words += $word.Text
  }
  $lines += [pscustomobject]@{
    text = $line.Text
    words = $words
  }
}

[pscustomobject]@{
  engine = 'Windows.Media.Ocr'
  language = 'en-US'
  preprocessing = 'alpha-mask crop white-background black-text scale-2x'
  text = $result.Text
  lineCount = $lines.Count
  lines = $lines
} | ConvertTo-Json -Depth 6
''';
