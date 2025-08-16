import 'package:flutter/material.dart';

/// 지역 선택 위젯
/// 시/도 드롭다운 선택
class RegionSelectorWidget extends StatefulWidget {
  final String? initialRegion;
  final Function(String) onRegionSelected;

  const RegionSelectorWidget({
    super.key,
    this.initialRegion,
    required this.onRegionSelected,
  });

  @override
  State<RegionSelectorWidget> createState() => _RegionSelectorWidgetState();
}

class _RegionSelectorWidgetState extends State<RegionSelectorWidget> {
  String? _selectedProvince;

  // 한국 시/도 목록 (구/군 데이터 제거)
  static const List<String> _koreanProvinces = [
    '서울특별시',
    '부산광역시',
    '대구광역시',
    '인천광역시',
    '광주광역시',
    '대전광역시',
    '울산광역시',
    '세종특별자치시',
    '경기도',
    '강원도',
    '충청북도',
    '충청남도',
    '전라북도',
    '전라남도',
    '경상북도',
    '경상남도',
    '제주특별자치도',
  ];

  @override
  void initState() {
    super.initState();
    _parseInitialRegion();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 초기 지역 정보를 파싱하여 시/도와 구/군으로 분리
  void _parseInitialRegion() {
    if (widget.initialRegion == null || widget.initialRegion!.isEmpty) {
      _selectedProvince = null;
      return;
    }

    final region = widget.initialRegion!.trim();

    // 시/도 명이 포함되어 있으면 설정
    for (String province in _koreanProvinces) {
      if (region.contains(province)) {
        _selectedProvince = province;
        setState(() {});
        return;
      }
    }

    // 정확한 매칭이 안 되면 앞글자로 시/도 추정
    for (String province in _koreanProvinces) {
      if (province.isNotEmpty && region.contains(province.substring(0, 2))) {
        _selectedProvince = province;
        setState(() {});
        break;
      }
    }
  }

  /// 시/도 선택 시 호출
  void _onProvinceSelected(String? province) {
    setState(() {
      _selectedProvince = province;
    });

    if (province != null) {
      // 시/도만 선택해도 콜백 호출
      widget.onRegionSelected(province);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1단계: 시/도 드롭다운
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white54),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedProvince,
              hint: const Text(
                '시/도 선택',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'Cafe24Oneprettynight',
                  fontSize: 16,
                ),
              ),
              dropdownColor: Colors.black87,
              iconEnabledColor: Colors.white,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Cafe24Oneprettynight',
                fontSize: 16,
              ),
              items: _koreanProvinces.map((String province) {
                return DropdownMenuItem<String>(
                  value: province,
                  child: Text(
                    province,
                    style: const TextStyle(
                      fontFamily: 'Cafe24Oneprettynight',
                      fontSize: 16,
                    ),
                  ),
                );
              }).toList(),
              onChanged: _onProvinceSelected,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
