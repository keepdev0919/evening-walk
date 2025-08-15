import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../widgets/region_selector_widget.dart';
import '../widgets/gender_selector_widget.dart';
// 이메일 로직 제거: 인스타그램 링크로 대체
import 'package:walk/src/features/auth/application/services/logout_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walk/src/features/auth/presentation/screens/login_page_screen.dart';
import 'package:walk/src/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:walk/src/core/services/log_service.dart';

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
                                        // 개발자에게 문의 버튼
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
                                        // 회원탈퇴 버튼 제거 (테스트 단계에서는 Firebase 콘솔에서 직접 삭제)
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
