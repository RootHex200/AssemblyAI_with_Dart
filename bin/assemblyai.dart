import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
Future<void> main() async {
  print("Welcome to AssemblyAI!");
  const API_TOKEN = "<your api token>";

  var filePath = p.join(Directory.current.path, 'assets', 'hello.mp4');

  final uploadUrl = await uploadFile(API_TOKEN, filePath);

  if (uploadUrl == null) {
    print("Upload failed. Please try again.");
    return;
  }

  final transcript = await transcribeAudio(API_TOKEN, uploadUrl);

  print("Transcript: ${transcript['text']}");
}

Future<String?> uploadFile(String apiToken, String path) async {
  print("Uploading file: $path");
  File file = File(path);
  var bytes =  file.readAsBytesSync();
  final url = "https://api.assemblyai.com/v2/upload";

  try {
    final dio = Dio();
    dio.options.headers.addAll({
      HttpHeaders.contentTypeHeader: "application/octet-stream",
      HttpHeaders.authorizationHeader: apiToken,
    });
    //binary data
    final response = await dio.post(url, data: Stream.fromIterable(bytes.map((e) => [e])));

    if (response.statusCode == 200) {
      final responseData = response.data;
      return responseData["upload_url"];
    } else {
      print("Error: ${response.statusCode} - ${response.statusMessage}");
      return null;
    }
  } catch (error) {
    print("Error: $error");
    return null;
  }
}

Future<Map<String, dynamic>> transcribeAudio(
    String apiToken, String audioUrl) async {
  print("Transcribing audio... This might take a moment.");

  final headers = {
    HttpHeaders.authorizationHeader: apiToken,
    HttpHeaders.contentTypeHeader: "application/json",
  };

  final url = "https://api.assemblyai.com/v2/transcript";
  final dio = Dio();

  try {
    final response = await dio.post(url,
        options: Options(headers: headers), data: {"audio_url": audioUrl});

    final responseData = response.data;
    final transcriptId = responseData["id"];

    final pollingEndpoint =
        "https://api.assemblyai.com/v2/transcript/$transcriptId";

    while (true) {
      final pollingResponse =
          await dio.get(pollingEndpoint, options: Options(headers: headers));
      final pollingResult = pollingResponse.data;

      if (pollingResult["status"] == "completed") {
        return pollingResult;
      } else if (pollingResult["status"] == "error") {
        throw Exception("Transcription failed: ${pollingResult["error"]}");
      } else {
        await Future.delayed(Duration(seconds: 3));
      }
    }
  } catch (error) {
    print("Error: $error");
    rethrow;
  }
}