import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DestinationEventCard extends StatefulWidget {
  final String question;
  final List<IconData> poseSuggestions;
  final Function(String answer, String? photoPath) onComplete;

  const DestinationEventCard({
    Key? key,
    required this.question,
    required this.poseSuggestions,
    required this.onComplete,
  }) : super(key: key);

  @override
  _DestinationEventCardState createState() => _DestinationEventCardState();
}

class _DestinationEventCardState extends State<DestinationEventCard> {
  final TextEditingController _textController = TextEditingController();
  XFile? _photoFile; // <<< 변수 선언 추가

  // 사진 촬영 로직 구현
  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _photoFile = photo;
        });
      }
    } catch (e) {
      print("Photo picker error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 질문 섹션
          Text(
            '경유지에서 떠올랐던 질문', 
            style: TextStyle(color: Colors.grey[600], fontSize: 14)
          ),
          const SizedBox(height: 8),
          Text(widget.question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // 답변 입력 섹션
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '어떤 생각을 하셨나요?',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // 사진 촬영 섹션
          const Text('지금의 순간을 사진으로 남겨보세요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: widget.poseSuggestions
                .map((icon) => Icon(icon, size: 40, color: Colors.grey[700]))
                .toList(),
          ),
          const SizedBox(height: 16),
          // 촬영된 사진 썸네일 표시
          if (_photoFile != null)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.file(
                  File(_photoFile!.path),
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (_photoFile != null) const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('사진 찍기'),
            onPressed: _takePhoto,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 32),

          // 완료 버튼
          ElevatedButton(
            child: const Text('산책 완료하기'),
            onPressed: () {
              widget.onComplete(_textController.text, _photoFile?.path);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ),
    );
  }
}