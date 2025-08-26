/// 문자열 유효성 검사를 위한 유틸리티 클래스
/// 앱 전반에서 사용되는 문자열 검증 로직을 중앙화
class StringValidationUtils {
  /// 플레이스홀더 문자들 (지역에 따라 반환되는 무의미한 문자들)
  static const _placeholderChars = {
    '.',
    '·',
    '-',
    '_',
    '?',
    '정보없음',
    'N/A',
    'null'
  };

  /// 주어진 문자열이 유효하지 않은 플레이스홀더인지 확인
  static bool isInvalidPlaceholder(String? value) {
    if (value == null) return true;

    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;

    // 소문자로 변환하여 대소문자 구분 없이 비교
    final lowerValue = trimmed.toLowerCase();
    return _placeholderChars.contains(lowerValue);
  }

  /// 문자열을 안전하게 정리 (null, 빈 문자열, 플레이스홀더 제거)
  static String? sanitizeString(String? value) {
    if (isInvalidPlaceholder(value)) return null;

    return value!.trim();
  }

  /// 여러 문자열 중 첫 번째 유효한 값 반환
  static String? getFirstValidString(List<String?> values) {
    for (final value in values) {
      final sanitized = sanitizeString(value);
      if (sanitized != null && sanitized.isNotEmpty) {
        return sanitized;
      }
    }
    return null;
  }

  // 이메일 검증 함수 제거 - 더 이상 사용하지 않음
  // static bool isValidEmail(String? email) { ... }

  /// 한국 전화번호 형식 검증
  static bool isValidKoreanPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return false;

    // 하이픈 제거 후 검증
    final cleanPhone = phone.replaceAll('-', '').replaceAll(' ', '');
    final phoneRegex = RegExp(r'^(010|011|016|017|018|019)[0-9]{7,8}$');
    return phoneRegex.hasMatch(cleanPhone);
  }

  /// 문자열 길이 검증 (최소/최대 길이)
  static bool isValidLength(String? value, {int? minLength, int? maxLength}) {
    if (value == null) return minLength == null || minLength == 0;

    final length = value.length;

    if (minLength != null && length < minLength) return false;
    if (maxLength != null && length > maxLength) return false;

    return true;
  }

  /// 닉네임 검증 (한글, 영문, 숫자, 언더스코어만 허용)
  static bool isValidNickname(String? nickname) {
    if (nickname == null || nickname.isEmpty) return false;
    if (!isValidLength(nickname, minLength: 2, maxLength: 12)) return false;

    final nicknameRegex = RegExp(r'^[가-힣a-zA-Z0-9_]+$');
    return nicknameRegex.hasMatch(nickname);
  }

  /// 문자열이 숫자로만 구성되어 있는지 확인
  static bool isNumericOnly(String? value) {
    if (value == null || value.isEmpty) return false;
    return RegExp(r'^[0-9]+$').hasMatch(value);
  }

  /// 문자열에서 숫자만 추출
  static String extractNumbers(String? value) {
    if (value == null) return '';
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// 안전한 문자열 비교 (null 처리 포함)
  static bool safeEquals(String? a, String? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a == b;
  }

  /// 문자열 목록에서 중복 제거 (순서 유지)
  static List<String> removeDuplicates(List<String?> values) {
    final seen = <String>{};
    final result = <String>[];

    for (final value in values) {
      final sanitized = sanitizeString(value);
      if (sanitized != null && !seen.contains(sanitized)) {
        seen.add(sanitized);
        result.add(sanitized);
      }
    }

    return result;
  }
}
