import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 산책 세션 데이터 모델
/// 하나의 완전한 산책 경험(출발지 → 경유지 → 목적지 → 출발지)을 저장
class WalkSession {
  final String id; // 고유 식별자
  final String userId; // 사용자 ID
  final DateTime startTime; // 산책 시작 시간
  final DateTime? endTime; // 산책 완료 시간
  final String selectedMate; // 선택한 동반자 ('혼자', '연인', '친구')
  
  // 위치 정보
  final LatLng startLocation; // 출발지
  final LatLng destinationLocation; // 목적지
  final LatLng waypointLocation; // 경유지
  
  // 경유지 경험
  final String? waypointQuestion; // 경유지에서 받은 질문
  final String? waypointAnswer; // 사용자의 답변
  
  // 목적지 경험
  final String? poseImageUrl; // 추천받은 포즈 이미지 URL
  final String? takenPhotoPath; // 찍은 사진 경로
  
  // 일기 정보
  final String? walkReflection; // 산책 후 소감 (일기 다이얼로그에서 입력)
  final List<String> hashtags; // 해시태그
  
  // 메타 정보
  final double? totalDistance; // 총 이동 거리 (km)
  final int? totalDuration; // 총 소요 시간 (분)
  final String? weatherInfo; // 날씨 정보
  final String? locationName; // 위치명 (예: "서울 강남구")
  
  WalkSession({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.selectedMate,
    required this.startLocation,
    required this.destinationLocation,
    required this.waypointLocation,
    this.waypointQuestion,
    this.waypointAnswer,
    this.poseImageUrl,
    this.takenPhotoPath,
    this.walkReflection,
    this.hashtags = const ['#저녁산책'],
    this.totalDistance,
    this.totalDuration,
    this.weatherInfo,
    this.locationName,
  });

  /// WalkStateManager의 데이터로부터 WalkSession 생성
  factory WalkSession.fromWalkStateManager({
    required String id,
    required String userId,
    required DateTime startTime,
    required LatLng startLocation,
    required LatLng destinationLocation,
    required LatLng waypointLocation,
    required String selectedMate,
    String? waypointQuestion,
    String? waypointAnswer,
    String? poseImageUrl,
    String? takenPhotoPath,
    String? walkReflection,
    List<String>? hashtags,
    String? weatherInfo,
    String? locationName,
    DateTime? endTime,
    int? totalDuration,
  }) {
    return WalkSession(
      id: id,
      userId: userId,
      startTime: startTime,
      endTime: endTime, // 전달받은 종료 시간 사용
      selectedMate: selectedMate,
      startLocation: startLocation,
      destinationLocation: destinationLocation,
      waypointLocation: waypointLocation,
      waypointQuestion: waypointQuestion,
      waypointAnswer: waypointAnswer,
      poseImageUrl: poseImageUrl,
      takenPhotoPath: takenPhotoPath,
      walkReflection: walkReflection,
      hashtags: hashtags ?? ['#저녁산책', '#포즈추천'],
      totalDuration: totalDuration, // 전달받은 총 소요 시간 사용
      weatherInfo: weatherInfo,
      locationName: locationName,
    );
  }

  /// Firebase Firestore에서 읽어온 데이터로부터 WalkSession 생성
  factory WalkSession.fromFirestore(Map<String, dynamic> data, String docId) {
    return WalkSession(
      id: docId,
      userId: data['userId'] ?? '',
      startTime: DateTime.fromMillisecondsSinceEpoch(data['startTime'] ?? 0),
      endTime: data['endTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['endTime'])
          : null,
      selectedMate: data['selectedMate'] ?? '혼자',
      startLocation: LatLng(
        data['startLocation']['latitude'] ?? 0.0,
        data['startLocation']['longitude'] ?? 0.0,
      ),
      destinationLocation: LatLng(
        data['destinationLocation']['latitude'] ?? 0.0,
        data['destinationLocation']['longitude'] ?? 0.0,
      ),
      waypointLocation: LatLng(
        data['waypointLocation']['latitude'] ?? 0.0,
        data['waypointLocation']['longitude'] ?? 0.0,
      ),
      waypointQuestion: data['waypointQuestion'],
      waypointAnswer: data['waypointAnswer'],
      poseImageUrl: data['poseImageUrl'],
      takenPhotoPath: data['takenPhotoPath'],
      walkReflection: data['walkReflection'],
      hashtags: List<String>.from(data['hashtags'] ?? ['#저녁산책']),
      totalDistance: data['totalDistance']?.toDouble(),
      totalDuration: data['totalDuration'],
      weatherInfo: data['weatherInfo'],
      locationName: data['locationName'],
    );
  }

  /// Firebase Firestore에 저장할 Map 형태로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'selectedMate': selectedMate,
      'startLocation': {
        'latitude': startLocation.latitude,
        'longitude': startLocation.longitude,
      },
      'destinationLocation': {
        'latitude': destinationLocation.latitude,
        'longitude': destinationLocation.longitude,
      },
      'waypointLocation': {
        'latitude': waypointLocation.latitude,
        'longitude': waypointLocation.longitude,
      },
      'waypointQuestion': waypointQuestion,
      'waypointAnswer': waypointAnswer,
      'poseImageUrl': poseImageUrl,
      'takenPhotoPath': takenPhotoPath,
      'walkReflection': walkReflection,
      'hashtags': hashtags,
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
      'weatherInfo': weatherInfo,
      'locationName': locationName,
      'createdAt': DateTime.now().millisecondsSinceEpoch, // 생성 시간 추가
    };
  }

  /// 산책이 완료되었는지 확인
  bool get isCompleted => endTime != null;

  /// 산책 소요 시간 계산 (분 단위)
  int? get durationInMinutes {
    if (endTime == null) return null;
    return endTime!.difference(startTime).inMinutes;
  }

  /// 동반자 이름을 표시용으로 변환
  String get mateDisplayName {
    switch (selectedMate) {
      case '혼자':
        return '나 혼자';
      case '연인':
        return '연인과 함께';
      case '친구':
        return '친구와 함께';
      default:
        return selectedMate;
    }
  }

  /// 간단한 요약 텍스트 생성 (홈화면 리스트용)
  String get summaryText {
    final duration = durationInMinutes;
    final durationText = duration != null ? '${duration}분' : '진행중';
    return '$mateDisplayName • $durationText';
  }

  /// 복사 생성자 (일부 필드 업데이트용)
  WalkSession copyWith({
    String? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    String? selectedMate,
    LatLng? startLocation,
    LatLng? destinationLocation,
    LatLng? waypointLocation,
    String? waypointQuestion,
    String? waypointAnswer,
    String? poseImageUrl,
    String? takenPhotoPath,
    String? walkReflection,
    List<String>? hashtags,
    double? totalDistance,
    int? totalDuration,
    String? weatherInfo,
    String? locationName,
  }) {
    return WalkSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      selectedMate: selectedMate ?? this.selectedMate,
      startLocation: startLocation ?? this.startLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      waypointLocation: waypointLocation ?? this.waypointLocation,
      waypointQuestion: waypointQuestion ?? this.waypointQuestion,
      waypointAnswer: waypointAnswer ?? this.waypointAnswer,
      poseImageUrl: poseImageUrl ?? this.poseImageUrl,
      takenPhotoPath: takenPhotoPath ?? this.takenPhotoPath,
      walkReflection: walkReflection ?? this.walkReflection,
      hashtags: hashtags ?? this.hashtags,
      totalDistance: totalDistance ?? this.totalDistance,
      totalDuration: totalDuration ?? this.totalDuration,
      weatherInfo: weatherInfo ?? this.weatherInfo,
      locationName: locationName ?? this.locationName,
    );
  }
}