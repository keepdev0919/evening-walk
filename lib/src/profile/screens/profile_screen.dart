import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../widgets/region_selector_widget.dart';
import '../widgets/gender_selector_widget.dart';
// 이메일 로직 제거: 인스타그램 링크로 대체
import 'package:walk/src/auth/services/logout_service.dart';
import 'package:walk/src/auth/services/account_deletion_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walk/src/auth/screens/login_page_screen.dart';
import 'package:walk/src/auth/screens/onboarding_screen.dart';
import 'package:walk/src/core/services/log_service.dart';
import 'package:walk/src/core/services/revenue_cat_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

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
  bool _isSaving = false; // 저장 중 로딩 상태
  Future<DocumentSnapshot>? _userFuture; // Firestore에서 사용자 정보를 가져오는 Future
  File? _image; // 갤러리에서 선택된 이미지 파일
  final ImagePicker _picker = ImagePicker(); // 이미지 선택을 위한 ImagePicker 인스턴스

  // 사용자 정보 입력을 위한 TextEditingController
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _sexController = TextEditingController();

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

    // 온보딩 진입 시 안내 스낵바 노출
    if (widget.isOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('회원 정보를 입력해주세요 ✨'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.black.withValues(alpha: 0.7),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    // 위젯이 dispose될 때 컨트롤러들을 정리합니다.
    _nicknameController.dispose();
    _ageController.dispose();
    _regionController.dispose();
    _sexController.dispose();
    // 이메일 컨트롤러 제거됨
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

    setState(() {
      _isSaving = true; // 저장 시작 시 로딩 상태 활성화
    });

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
      // 이메일 저장 제거
    };

    LogService.debug('UI', '저장할 지역 데이터: ${_regionController.text}');
    LogService.debug('UI', '저장할 전체 데이터: $dataToUpdate');

    // 이미지 URL이 있으면 데이터에 추가합니다.
    if (imageUrl != null) {
      dataToUpdate['profileImageUrl'] = imageUrl;
    }

    // Firestore에 데이터를 업데이트합니다.
    await _firestore.collection('users').doc(_user!.uid).update(dataToUpdate);

    setState(() {
      _isEditing = false; // 수정 모드 비활성화
      _isSaving = false; // 저장 완료 시 로딩 상태 비활성화
      // 사용자 정보를 다시 불러와 화면을 갱신합니다.
      _userFuture = _firestore.collection('users').doc(_user!.uid).get();
      _image = null; // 로컬 이미지 선택 초기화
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('프로필이 업데이트되었습니다. ✨'),
        backgroundColor: Colors.black.withValues(alpha: 0.6),
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
        automaticallyImplyLeading: false, // 자동 뒤로가기 버튼 비활성화
        centerTitle: true, // 제목을 항상 가운데 정렬
        titleSpacing: 0, // 제목 간격 조정으로 가운데 정렬 보장
        iconTheme: const IconThemeData(color: Colors.white), // 아이콘 색상 변경
        title: const Text(
          '내 정보',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            // 첫 사용자(온보딩)의 경우 뒤로가기 완전 차단
            if (widget.isOnboarding) {
              // 온보딩 중에는 뒤로가기 불가 - 사용자에게 안내
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('프로필 정보를 입력해주세요 ✨'),
                  backgroundColor: Colors.black.withValues(alpha: 0.7),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }

            if (_isEditing) {
              // 편집 모드일 때: 편집 모드 취소
              final userDoc =
                  await _firestore.collection('users').doc(_user!.uid).get();
              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>;
                setState(() {
                  _isEditing = false; // 편집 모드 취소
                  // TextEditingController의 값을 원래 데이터로 되돌리기
                  _nicknameController.text = userData['nickname'] ?? '';
                  _ageController.text = userData['age']?.toString() ?? '';
                  _regionController.text = userData['region'] ?? '';
                  _sexController.text = userData['sex'] ?? '';
                  _image = null; // 로컬 이미지 선택 초기화
                });
              } else {
                setState(() {
                  _isEditing = false;
                  _image = null;
                });
              }
            } else {
              // 편집 모드가 아닐 때: 홈화면으로 이동
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/homescreen',
                (route) => false,
              );
            }
          },
        ),
        actions: [
          // 사용방법(온보딩) 안내 아이콘 (수정 모드일 때는 숨김)
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.white),
              tooltip: '사용 방법 보기',
              onPressed: () async {
                final goOnboarding = await showDialog<bool>(
                  context: context,
                  barrierDismissible: true,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Colors.black.withValues(alpha: 0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.white24, width: 1),
                    ),
                    title: const Text(
                      '이용 안내 보기',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    content: const Text(
                      '저녁산책의 사용 방법을 \n다시 보시겠어요?',
                      style: TextStyle(
                          color: Colors.white70,
                          height: 1.3,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('취소',
                            style: TextStyle(color: Colors.white70)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.blueAccent.withValues(alpha: 0.9),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('확인'),
                      ),
                    ],
                  ),
                );
                if (goOnboarding == true && mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const Onboarding()),
                  );
                }
              },
            ),
          // 수정/저장 버튼
          IconButton(
            icon: _isEditing
                ? _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white)
                : const Icon(Icons.edit, color: Colors.white),
            onPressed: _isSaving
                ? null // 저장 중일 때는 버튼 비활성화
                : () {
                    if (_isEditing) {
                      if (!_validateProfileAndWarn()) return;
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
            color: Colors.black.withValues(alpha: 0.5),
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
                                onTap: () {
                                  if (_isEditing) {
                                    _pickImage();
                                  } else {
                                    final String? url =
                                        (userData['profileImageUrl']
                                            as String?);
                                    if (_image != null) {
                                      _showFullScreenProfileImage(
                                        filePath: _image!.path,
                                      );
                                    } else if (url != null && url.isNotEmpty) {
                                      _showFullScreenProfileImage(
                                        imageUrl: url,
                                      );
                                    }
                                  }
                                },
                                child: Column(
                                  children: [
                                    // 프로필 이미지 표시
                                    CircleAvatar(
                                      radius: 60,
                                      backgroundColor: Colors.white54,
                                      backgroundImage: _image != null
                                          ? FileImage(_image!)
                                          : ((userData['profileImageUrl'] !=
                                                      null &&
                                                  (userData['profileImageUrl']
                                                          as String)
                                                      .isNotEmpty)
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
                              // 이메일 입력 필드 제거
                              if (!widget.isOnboarding && !_isEditing) ...[
                                const SizedBox(height: 16),
                                // 로그아웃 버튼 (온보딩 모드에서는 숨김)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0, horizontal: 20.0),
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        // 후원 버튼 (위치 변경)
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.coffee,
                                              color: Colors.orange, size: 18),
                                          label: const Text(
                                            '개발자야 커피먹고 일더해라! ☕',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            backgroundColor: Colors.orange
                                                .withValues(alpha: 0.15),
                                            side: BorderSide(
                                                color: Colors.orange
                                                    .withValues(alpha: 0.4)),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12, horizontal: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ).copyWith(
                                            overlayColor:
                                                const WidgetStatePropertyAll(
                                              Color.fromRGBO(255, 165, 0, 0.2),
                                            ),
                                          ),
                                          onPressed: () =>
                                              _showDonationDialog(),
                                        ),
                                        // 개발자에게 문의 버튼 (위치 변경)
                                        OutlinedButton.icon(
                                          icon: const Icon(
                                              Icons.contact_support,
                                              color: Colors.white70,
                                              size: 18),
                                          label: const Text(
                                            '개발자에게 문의하기',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.08),
                                            side: BorderSide(
                                                color: Colors.white
                                                    .withValues(alpha: 0.25)),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12, horizontal: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ).copyWith(
                                            overlayColor:
                                                const WidgetStatePropertyAll(
                                              Color.fromRGBO(
                                                  255, 255, 255, 0.12),
                                            ),
                                          ),
                                          onPressed: () => _contactDeveloper(),
                                        ),
                                        // 로그아웃 버튼
                                        OutlinedButton.icon(
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
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.08),
                                            side: BorderSide(
                                                color: Colors.white
                                                    .withValues(alpha: 0.25)),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12, horizontal: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ).copyWith(
                                            overlayColor:
                                                const WidgetStatePropertyAll(
                                              Color.fromRGBO(
                                                  255, 255, 255, 0.12),
                                            ),
                                          ),
                                          onPressed: _confirmAndLogout,
                                        ),
                                        // 회원탈퇴 버튼
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.delete_forever,
                                              color: Colors.redAccent,
                                              size: 18),
                                          label: const Text(
                                            '회원탈퇴',
                                            style: TextStyle(
                                                color: Colors.redAccent,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                            backgroundColor: Colors.redAccent
                                                .withValues(alpha: 0.08),
                                            side: BorderSide(
                                                color: Colors.redAccent
                                                    .withValues(alpha: 0.4)),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12, horizontal: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ).copyWith(
                                            overlayColor:
                                                const WidgetStatePropertyAll(
                                              Color.fromRGBO(244, 67, 54, 0.12),
                                            ),
                                          ),
                                          onPressed: _confirmAndDeleteAccount,
                                        ),
                                      ],
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

  /// 프로필 이미지를 전체 화면으로 보여주는 다이얼로그를 띄웁니다.
  void _showFullScreenProfileImage({String? imageUrl, String? filePath}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: (filePath != null)
                  ? Image.file(
                      File(filePath),
                      fit: BoxFit.contain,
                    )
                  : (imageUrl != null)
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                        )
                      : const SizedBox.shrink(),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 로그아웃 확인 다이얼로그 후 로그아웃 실행
  Future<void> _confirmAndLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
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
              backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
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
          content: const Text('로그아웃되었습니다. ✨'),
          backgroundColor: Colors.black.withValues(alpha: 0.7),
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
          content: Text('로그아웃 중 오류가 발생했습니다: $e ✨'),
          backgroundColor: Colors.red.withValues(alpha: 0.85),
        ),
      );
    }
  }

  /// 실제 로그아웃 처리 (서비스 호출)
  Future<void> _performLogout() async {
    await AuthLogoutService.signOut();
  }

  /// 회원탈퇴 확인 다이얼로그 후 회원탈퇴 실행
  Future<void> _confirmAndDeleteAccount() async {
    // 1단계: 회원탈퇴 경고 다이얼로그
    final shouldProceed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            const Text('회원탈퇴 경고',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          '정말로 회원탈퇴를 진행하시겠습니까?\n\n⚠️ 이 작업은 되돌릴 수 없습니다.\n⚠️ 모든 데이터가 영구적으로 삭제됩니다.\n⚠️ 산책 기록, 프로필 정보 등이 모두 사라집니다.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
              foregroundColor: Colors.white,
            ),
            child: const Text('진행'),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    // 2단계: 최종 확인 다이얼로그
    final finalConfirmation = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.redAccent, size: 28),
            const SizedBox(width: 8),
            const Text('최종 확인',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          '회원탈퇴를 최종 확인합니다.\n\n이 작업을 진행하면:\n• 계정이 영구적으로 삭제됩니다\n• 모든 데이터가 복구 불가능합니다\n• 앱을 다시 사용하려면 재가입이 필요합니다\n\n정말로 진행하시겠습니까?',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('아니오', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('네, 탈퇴합니다'),
          ),
        ],
      ),
    );

    if (finalConfirmation != true) return;

    // 실제 회원탈퇴 실행 (타임아웃 처리 포함)
    try {
      if (!mounted) return;

      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.redAccent),
              SizedBox(height: 16),
              Text(
                '회원탈퇴를 진행하고 있습니다...',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                '이 작업은 최대 30초 정도 소요될 수 있습니다.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      // 회원탈퇴 서비스 실행 (타임아웃 30초)
      final result = await Future.any([
        AccountDeletionService().deleteAccount(),
        Future.delayed(const Duration(seconds: 30)).then((_) => 
          AccountDeletionResult(
            isSuccess: false, 
            message: '회원탈퇴 처리 시간이 초과되었습니다. 네트워크를 확인하고 다시 시도해주세요.',
            failedStep: '타임아웃',
          )
        ),
      ]);

      if (!mounted) return;

      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();

      if (result.isSuccess) {
        // 성공 시 완료 다이얼로그
        await _showAccountDeletionSuccessDialog();
      } else {
        // 실패 시 에러 다이얼로그 (실패한 단계 정보 포함)
        _showAccountDeletionErrorDialog(result.message, result.failedStep);
      }
    } catch (e) {
      if (!mounted) return;

      // 로딩 다이얼로그 닫기 (안전하게)
      try {
        Navigator.of(context).pop();
      } catch (_) {
        // 다이얼로그가 이미 닫힌 경우 무시
      }

      _showAccountDeletionErrorDialog('회원탈퇴 처리 중 예상치 못한 오류가 발생했습니다: $e', '예상치못한오류');
    }
  }

  /// 회원탈퇴 성공 다이얼로그 표시
  Future<void> _showAccountDeletionSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.green, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            const Text('회원탈퇴 완료',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: const Text(
          '회원탈퇴가 성공적으로 완료되었습니다.\n\n✓ 모든 개인 데이터 삭제 완료\n✓ 산책 기록 삭제 완료\n✓ 계정 삭제 완료\n\n그동안 저녁 산책을 이용해주셔서 감사했습니다.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // 안전한 로그아웃 및 화면 전환
              await _safeLogoutAndNavigate();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('로그인 화면으로', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// 회원탈퇴 실패 다이얼로그 표시 (상세 정보 포함)
  void _showAccountDeletionErrorDialog(String errorMessage, [String? failedStep]) {
    String detailedMessage = errorMessage;
    
    // 실패한 단계에 따른 추가 안내 메시지
    if (failedStep != null) {
      switch (failedStep) {
        case 'Firestore 데이터 삭제':
          detailedMessage += '\n\n희드지만 일부 데이터가 삭제되었을 수 있습니다.';
          break;
        case 'Storage 데이터 삭제':
          detailedMessage += '\n\n계정 데이터는 삭제되었지만 사진 파일 삭제에 문제가 있었습니다.';
          break;
        case 'Auth 계정 삭제':
          detailedMessage += '\n\n데이터는 삭제되었지만 계정 삭제에 문제가 있었습니다. 잠시 후 다시 시도해주세요.';
          break;
        case '타임아웃':
          detailedMessage += '\n\n네트워크 연결을 확인하고 WiFi나 모바일 데이터가 안정적인지 확인해주세요.';
          break;
      }
    }
    
    // 더 상세한 오류 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            const Text('회원탈퇴 실패',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            detailedMessage,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인', 
                style: TextStyle(color: Colors.white70)),
          ),
          if (failedStep == '타임아웃' || failedStep == 'Auth 계정 삭제')
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // 재시도 로직
                _confirmAndDeleteAccount();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                foregroundColor: Colors.white,
              ),
              child: const Text('다시 시도'),
            ),
        ],
      ),
    );
  }

  /// 안전한 로그아웃 및 화면 전환
  Future<void> _safeLogoutAndNavigate() async {
    try {
      LogService.info('Profile', '회원탈퇴 성공 후 로그인 화면으로 이동 시작');
      
      // 1단계: Firebase Auth에서 로그아웃 (이미 삭제된 계정일 수 있음)
      try {
        await FirebaseAuth.instance.signOut();
        LogService.info('Profile', '로그아웃 완료');
      } catch (e) {
        // 계정이 이미 삭제된 경우 로그아웃 실패할 수 있음
        LogService.info('Profile', '로그아웃 실패 (계정 이미 삭제된 경우): $e');
      }

      // 2단계: 잠시 대기 (Firebase 상태 동기화)
      await Future.delayed(const Duration(milliseconds: 500));

      // 3단계: 로그인 화면으로 이동 (모든 이전 화면 제거)
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      // 로그아웃 실패 시에도 강제로 화면 전환
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  /// 개발자에게 문의 - 인스타그램 계정으로 이동
  void _contactDeveloper() {
    // 인앱 브라우저 없이 외부 브라우저로 열기 (url_launcher 필요)
    _launchInstagram();
  }

  Future<void> _launchInstagram() async {
    final appUri = Uri.parse('instagram://user?username=evening._.walk');
    final webUri = Uri.parse('https://www.instagram.com/evening._.walk');
    try {
      if (await canLaunchUrl(appUri)) {
        final ok =
            await launchUrl(appUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      final okWeb =
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (!okWeb && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('인스타그램을 열 수 없습니다. ✨'),
            backgroundColor: Colors.red.withValues(alpha: 0.85),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('인스타그램을 열 수 없습니다. ✨'),
          backgroundColor: Colors.red.withValues(alpha: 0.85),
        ),
      );
    }
  }

  // 회원탈퇴 기능은 테스트 단계에서 비활성화되었습니다.

  /// 후원 다이얼로그 표시
  void _showDonationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _DonationDialog(),
    );
  }

  /// 편집 모드가 아닐 때 편집 안내 스낵바를 표시합니다.
  /// 역할: 사용자가 화면을 터치하면 우측 상단 연필 아이콘을 안내합니다.
  void _showEditHintSnackBar() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('상단 연필 아이콘을 누르면 편집할 수 있어요. ✨'),
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 프로필 유효성 검사 + 항목별 스낵바 안내
  bool _validateProfileAndWarn() {
    String nickname = _nicknameController.text.trim();
    String ageText = _ageController.text.trim();
    String region = _regionController.text.trim();
    String sex = _sexController.text.trim();
    // 이메일은 더 이상 수집하지 않습니다.

    SnackBar _sb(String msg) => SnackBar(
          content: Text('$msg ✨'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.black.withValues(alpha: 0.75),
          behavior: SnackBarBehavior.floating,
        );

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (nickname.isEmpty) {
      messenger.showSnackBar(_sb('닉네임을 입력해주세요'));
      return false;
    }
    if (ageText.isEmpty) {
      messenger.showSnackBar(_sb('나이를 입력해주세요'));
      return false;
    }
    final int? age = int.tryParse(ageText);
    if (age == null) {
      messenger.showSnackBar(_sb('나이는 숫자로 입력해주세요'));
      return false;
    }
    if (age <= 0) {
      messenger.showSnackBar(_sb('나이는 1 이상의 숫자여야 해요'));
      return false;
    }
    if (region.isEmpty) {
      messenger.showSnackBar(_sb('지역을 선택해주세요'));
      return false;
    }
    if (sex.isEmpty) {
      messenger.showSnackBar(_sb('성별을 선택해주세요'));
      return false;
    }
    // 이메일 유효성 검사는 더 이상 필요하지 않습니다.
    return true;
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
                    maxLength: 300,
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
                      counterText: '', // 글자 수 카운터를 숨김
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
                    LogService.debug('UI', '지역 선택됨: $region');
                    controller.text = region;
                    LogService.debug('UI', '컨트롤러 업데이트됨: ${controller.text}');
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

/// 후원 다이얼로그 위젯
class _DonationDialog extends StatefulWidget {
  @override
  State<_DonationDialog> createState() => _DonationDialogState();
}

class _DonationDialogState extends State<_DonationDialog> {
  final RevenueCatService _revenueCatService = RevenueCatService();
  bool _isLoading = true;
  bool _isPurchasing = false;
  List<Package> _packages = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    try {
      await _revenueCatService.refreshOfferings();
      final packages = _revenueCatService.getDonationPackages();

      setState(() {
        _packages = packages;
        _isLoading = false;
        _errorMessage = packages.isEmpty ? '후원 상품을 불러올 수 없습니다.' : null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '후원 상품 로드 중 오류가 발생했습니다.';
      });
    }
  }

  Future<void> _makePurchase(Package package) async {
    setState(() {
      _isPurchasing = true;
    });

    try {
      final result = await _revenueCatService.makeDonation(package);

      if (!mounted) return;

      if (result.isSuccess) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green.withValues(alpha: 0.9),
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (!result.isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red.withValues(alpha: 0.9),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.orange, width: 2),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목
            Row(
              children: [
                const Icon(Icons.coffee, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '개발자 후원하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: 60,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // 설명 텍스트
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Text(
                '저녁산책 앱이 도움이 되셨다면\n개발자에게 커피 한 잔..?! ☕',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // 로딩/에러/상품 목록 표시
            Flexible(
              child: _buildContent(),
            ),

            const SizedBox(height: 16),

            // 구매 복원 버튼
            TextButton(
              onPressed: _isPurchasing ? null : _restorePurchases,
              child: const Text(
                '구매 복원',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text(
              '후원 상품을 불러오는 중...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPackages,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _packages.length,
      itemBuilder: (context, index) {
        final package = _packages[index];
        final product = package.storeProduct;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            onPressed: _isPurchasing ? null : () => _makePurchase(package),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.withValues(alpha: 0.9),
              foregroundColor: Colors.white,
              elevation: 4,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isPurchasing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Column(
                    children: [
                      Text(
                        product.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.priceString,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (product.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }

  Future<void> _restorePurchases() async {
    final result = await _revenueCatService.restorePurchases();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.isSuccess
            ? Colors.green.withValues(alpha: 0.9)
            : Colors.red.withValues(alpha: 0.9),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
