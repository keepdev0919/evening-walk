import 'package:cloud_firestore/cloud_firestore.dart';

/// 산책 중 경유지에서 제공되는 질문 데이터 모델
class QuestionModel {
  final String id;
  final String text;
  final String mate; // '혼자', '연인', '친구', '반려견', '가족'
  final String? category; // 질문 카테고리 (예: 'reflection', 'couple', 'game', 'talk')
  final String? subType; // 친구용 세부 타입 ('two', 'many')
  final String? questionType; // 친구용 질문 유형 ('talk', 'game')
  final bool isActive; // 활성화 여부 (비활성화된 질문은 노출되지 않음)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? order; // 질문 우선순위 (낮은 숫자가 우선)

  QuestionModel({
    required this.id,
    required this.text,
    required this.mate,
    this.category,
    this.subType,
    this.questionType,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.order,
  });

  /// Firestore 문서에서 QuestionModel 생성
  factory QuestionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuestionModel(
      id: doc.id,
      text: data['text'] ?? '',
      mate: data['mate'] ?? '',
      category: data['category'],
      subType: data['subType'],
      questionType: data['questionType'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      order: data['order'],
    );
  }

  /// Firestore에 저장할 Map 형태로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'mate': mate,
      'category': category,
      'subType': subType,
      'questionType': questionType,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'order': order,
    };
  }

  /// 복사 생성자
  QuestionModel copyWith({
    String? id,
    String? text,
    String? mate,
    String? category,
    String? subType,
    String? questionType,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? order,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      text: text ?? this.text,
      mate: mate ?? this.mate,
      category: category ?? this.category,
      subType: subType ?? this.subType,
      questionType: questionType ?? this.questionType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      order: order ?? this.order,
    );
  }

  @override
  String toString() {
    return 'QuestionModel(id: $id, text: $text, mate: $mate, category: $category, subType: $subType, questionType: $questionType, isActive: $isActive)';
  }
}