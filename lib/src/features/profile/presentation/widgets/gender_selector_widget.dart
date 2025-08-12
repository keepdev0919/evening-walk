import 'package:flutter/material.dart';

/// 성별 선택 드롭다운 위젯
class GenderSelectorWidget extends StatefulWidget {
  final String? initialGender;
  final Function(String) onGenderSelected;

  const GenderSelectorWidget({
    super.key,
    this.initialGender,
    required this.onGenderSelected,
  });

  @override
  State<GenderSelectorWidget> createState() => _GenderSelectorWidgetState();
}

class _GenderSelectorWidgetState extends State<GenderSelectorWidget> {
  String? _selectedGender;

  static const List<String> _genderOptions = ['남자', '여자'];

  @override
  void initState() {
    super.initState();
    _selectedGender = widget.initialGender;
  }

  void _onGenderSelected(String? gender) {
    setState(() {
      _selectedGender = gender;
    });
    
    if (gender != null) {
      widget.onGenderSelected(gender);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white54),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGender,
          hint: const Text(
            '성별 선택',
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
          items: _genderOptions.map((String gender) {
            return DropdownMenuItem<String>(
              value: gender,
              child: Text(
                gender,
                style: const TextStyle(
                  fontFamily: 'Cafe24Oneprettynight',
                  fontSize: 16,
                ),
              ),
            );
          }).toList(),
          onChanged: _onGenderSelected,
        ),
      ),
    );
  }
}