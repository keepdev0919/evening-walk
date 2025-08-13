import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../widgets/region_selector_widget.dart';
import '../widgets/gender_selector_widget.dart';
import 'package:walk/src/features/auth/application/services/logout_service.dart';
import 'package:walk/src/features/auth/presentation/screens/login_page_screen.dart';
import 'package:walk/src/features/auth/presentation/screens/onboarding_screen.dart';

/// 사용자 프로필을 표시하고 수정하는 페이지입니다.
class Profile extends StatefulWidget {
  /// 온보딩에서 호출 시 true로 전달하면 처음부터 수정 모드로 시작하고
  /// 저장 후 온보딩 화면으로 진행합니다.
  final bool isOnboarding;

  const Profile({super.key, this.isOnboarding = false});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  // Firebase 서비스 인스턴스
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? _user; // 현재 로그인된 사용자
  bool _isEditing = false; // 수정 모드 활성화 여부
  Future<DocumentSnapshot>? _userFuture; // Firestore에서 사용자 정보를 가져오는 Future
  File? _image; // 갤러리에서 선택된 이미지 파일
  final ImagePicker _picker = ImagePicker(); // 이미지 선택을 위한 ImagePicker 인스턴스

  // 사용자 정보 입력을 위한 TextEditingController
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _sexController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    // 온보딩 진입이면 수정 모드로 시작
    _isEditing = widget.isOnboarding ? true : false;
    if (_user != null) {
      // 현재 사용자의 정보를 Firestore에서 가져옵니다.
      _userFuture = _firestore.collection('users').doc(_user!.uid).get();
    }
  }

  @override
  void dispose() {
    // 위젯이 dispose될 때 컨트롤러들을 정리합니다.
    _nicknameController.dispose();
    _ageController.dispose();
    _regionController.dispose();
    _sexController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// 갤러리에서 이미지를 선택하는 함수입니다.
  Future<void> _pickImage() async {
    if (!_isEditing) return; // 수정 모드가 아닐 때는 이미지 선택 비활성화
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  /// 프로필 정보를 Firestore와 Storage에 업데이트하는 함수입니다.
  Future<void> _updateProfile() async {
    if (_user == null) return;

    String? imageUrl;
    // 새 이미지가 선택된 경우 Storage에 업로드하고 URL을 가져옵니다.
    if (_image != null) {
      final ref = _storage
          .ref()
          .child('profile_images')
          .child(_user!.uid)
          .child('profile.jpg');
      await ref.putFile(_image!);
      imageUrl = await ref.getDownloadURL();
    }

    // 업데이트할 데이터를 Map으로 구성합니다.
    Map<String, dynamic> dataToUpdate = {
      'nickname': _nicknameController.text,
      'age': int.tryParse(_ageController.text),
      'region': _regionController.text,
      'sex': _sexController.text,
      'email': _emailController.text,
    };

    print('저장할 지역 데이터: ${_regionController.text}'); // 디버그 로그
    print('저장할 전체 데이터: $dataToUpdate'); // 디버그 로그

    // 이미지 URL이 있으면 데이터에 추가합니다.
    if (imageUrl != null) {
      dataToUpdate['profileImageUrl'] = imageUrl;
    }

    // Firestore에 데이터를 업데이트합니다.
    await _firestore.collection('users').doc(_user!.uid).update(dataToUpdate);

    setState(() {
      _isEditing = false; // 수정 모드 비활성화
      // 사용자 정보를 다시 불러와 화면을 갱신합니다.
      _userFuture = _firestore.collection('users').doc(_user!.uid).get();
      _image = null; // 로컬 이미지 선택 초기화
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('프로필이 업데이트되었습니다.'),
        backgroundColor: Colors.black.withOpacity(0.6),
        duration: const Duration(seconds: 2),
      ),
    );

    // 온보딩 진입이었다면, 저장 후 온보딩 화면으로 이동
    if (widget.isOnboarding && mounted) {
      await Future.delayed(const Duration(milliseconds: 250));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Onboarding()),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // body를 AppBar 뒤까지 확장
      appBar: AppBar(
        backgroundColor: Colors.transparent, // 배경색 투명
        elevation: 0, // 그림자 제거
        iconTheme: const IconThemeData(color: Colors.white), // 뒤로가기 아이콘 색상 변경
        title: const Text(
          '내 정보',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // 수정/저장 버튼
          IconButton(
            icon:
                Icon(_isEditing ? Icons.save : Icons.edit, color: Colors.white),
            onPressed: () {
              if (_isEditing) {
                _updateProfile(); // 저장 로직 실행
              } else {
                setState(() {
                  _isEditing = true; // 수정 모드 활성화
                });
              }
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경 이미지
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/nature_walk.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // 반투명 오버레이
          Container(
            color: Colors.black.withOpacity(0.5),
          ),
          _user == null
              ? const Center(
                  child: Text('로그인이 필요합니다.',
                      style: TextStyle(color: Colors.white)))
              : FutureBuilder<DocumentSnapshot>(
                  future: _userFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text('데이터를 불러오는 중 오류가 발생했습니다.',
                              style: TextStyle(color: Colors.white)));
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(
                          child: Text('사용자 정보를 찾을 수 없습니다.',
                              style: TextStyle(color: Colors.white)));
                    }

                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    // 수정 모드가 아닐 때만 컨트롤러의 텍스트를 Firestore 데이터로 설정합니다.
                    if (!_isEditing) {
                      _nicknameController.text = userData['nickname'] ?? '';
                      _ageController.text = userData['age']?.toString() ?? '';
                      _regionController.text = userData['region'] ?? '';
                      _sexController.text = userData['sex'] ?? '';
                      _emailController.text = userData['email'] ?? '';
                    }

                    return SafeArea(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (!_isEditing) {
                            _showEditHintSnackBar();
                          }
                        },
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20), // AppBar 공간 확보
                              GestureDetector(
                                onTap: _pickImage,
                                child: Column(
                                  children: [
                                    // 프로필 이미지 표시
                                    CircleAvatar(
                                      radius: 60,
                                      backgroundColor: Colors.white54,
                                      backgroundImage: _image != null
                                          ? FileImage(_image!)
                                          : (userData['profileImageUrl'] != null
                                              ? NetworkImage(
                                                  userData['profileImageUrl'])
                                              : null) as ImageProvider?,
                                      child: _image == null &&
                                              userData['profileImageUrl'] ==
                                                  null
                                          ? const Icon(Icons.person,
                                              size: 60, color: Colors.white)
                                          : null,
                                    ),
                                    // 수정 모드일 때 '이미지 변경' 텍스트 표시
                                    if (_isEditing)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 12.0),
                                        child: Text('이미지 변경',
                                            style: TextStyle(
                                                color: Colors.blueAccent,
                                                fontSize: 16)),
                                      )
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),
                              // 각 정보 필드를 생성합니다.
                              _buildInfoField('닉네임', _nicknameController),
                              _buildInfoField('나이', _ageController,
                                  keyboardType: TextInputType.number),
                              _buildRegionField('지역', _regionController),
                              _buildGenderField('성별', _sexController),
                              _buildInfoField('이메일', _emailController,
                                  keyboardType: TextInputType.emailAddress),
                              if (!widget.isOnboarding) ...[
                                const SizedBox(height: 16),
                                // 로그아웃 버튼 (온보딩 모드에서는 숨김)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0, horizontal: 20.0),
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.logout,
                                          color: Colors.white70, size: 18),
                                      label: const Text(
                                        '로그아웃',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor:
                                            Colors.white.withOpacity(0.08),
                                        side: BorderSide(
                                            color:
                                                Colors.white.withOpacity(0.25)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ).copyWith(
                                        overlayColor:
                                            const MaterialStatePropertyAll(
                                          Color.fromRGBO(255, 255, 255, 0.12),
                                        ),
                                      ),
                                      onPressed: _confirmAndLogout,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  /// 로그아웃 확인 다이얼로그 후 로그아웃 실행
  Future<void> _confirmAndLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24, width: 1),
        ),
        title: const Text('로그아웃',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content:
            const Text('로그아웃하시겠습니까?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.9),
              foregroundColor: Colors.white,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    // 실제 로그아웃 실행
    try {
      // 지연 import 방지: 파일 상단에 의존성 추가하지 않기 위해 동적 import 불가 → 상단에 import 추가 필요
      // ignore: use_build_context_synchronously
      await _performLogout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('로그아웃되었습니다.'),
          backgroundColor: Colors.black.withOpacity(0.7),
          duration: const Duration(seconds: 2),
        ),
      );
      // 로그인 화면으로 이동하며 기존 스택 제거
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그아웃 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red.withOpacity(0.85),
        ),
      );
    }
  }

  /// 실제 로그아웃 처리 (서비스 호출)
  Future<void> _performLogout() async {
    await AuthLogoutService.signOut();
  }

  /// 편집 모드가 아닐 때 편집 안내 스낵바를 표시합니다.
  /// 역할: 사용자가 화면을 터치하면 우측 상단 연필 아이콘을 안내합니다.
  void _showEditHintSnackBar() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('오른쪽 위 연필 아이콘을 누르면 편집할 수 있어요.'),
        backgroundColor: Colors.black.withOpacity(0.6),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 사용자 정보 필드를 생성하는 위젯입니다.
  Widget _buildInfoField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white54),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _isEditing
                ? TextField(
                    controller: controller,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Cafe24Oneprettynight',
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '$label 입력',
                      hintStyle: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Cafe24Oneprettynight',
                        fontSize: 16,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    keyboardType: keyboardType,
                  )
                : Text(
                    controller.text.isEmpty ? '$label 없음' : controller.text,
                    style: TextStyle(
                      color: controller.text.isEmpty
                          ? Colors.white70
                          : Colors.white,
                      fontFamily: 'Cafe24Oneprettynight',
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 지역 선택 필드를 생성하는 위젯입니다.
  Widget _buildRegionField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          _isEditing
              ? RegionSelectorWidget(
                  initialRegion: controller.text,
                  onRegionSelected: (region) {
                    print('지역 선택됨: $region'); // 디버그 로그
                    controller.text = region;
                    print('컨트롤러 업데이트됨: ${controller.text}'); // 디버그 로그
                  },
                )
              : Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white54),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    controller.text.isEmpty ? '$label 없음' : controller.text,
                    style: TextStyle(
                      color: controller.text.isEmpty
                          ? Colors.white70
                          : Colors.white,
                      fontFamily: 'Cafe24Oneprettynight',
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  /// 성별 선택 필드를 생성하는 위젯입니다.
  Widget _buildGenderField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          _isEditing
              ? GenderSelectorWidget(
                  initialGender: controller.text,
                  onGenderSelected: (gender) {
                    controller.text = gender;
                  },
                )
              : Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white54),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    controller.text.isEmpty ? '$label 없음' : controller.text,
                    style: TextStyle(
                      color: controller.text.isEmpty
                          ? Colors.white70
                          : Colors.white,
                      fontFamily: 'Cafe24Oneprettynight',
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
