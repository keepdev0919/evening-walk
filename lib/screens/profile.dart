import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? _user;
  bool _isEditing = false;
  Future<DocumentSnapshot>? _userFuture;
  File? _image;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _sexController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    if (_user != null) {
      _userFuture = _firestore.collection('users').doc(_user!.uid).get();
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _ageController.dispose();
    _regionController.dispose();
    _sexController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (!_isEditing) return; // Only allow picking image in edit mode
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_user == null) return;

    String? imageUrl;
    if (_image != null) {
      final ref = _storage.ref().child('profile_images').child('${_user!.uid}.jpg');
      await ref.putFile(_image!);
      imageUrl = await ref.getDownloadURL();
    }

    Map<String, dynamic> dataToUpdate = {
      'nickname': _nicknameController.text,
      'age': int.tryParse(_ageController.text),
      'region': _regionController.text,
      'sex': _sexController.text,
      'email': _emailController.text,
    };

    if (imageUrl != null) {
      dataToUpdate['profileImageUrl'] = imageUrl;
    }

    await _firestore.collection('users').doc(_user!.uid).update(dataToUpdate);

    setState(() {
      _isEditing = false;
      _userFuture = _firestore.collection('users').doc(_user!.uid).get();
      _image = null; // Clear the local image after upload
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('프로필이 업데이트되었습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 정보'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _updateProfile();
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: _user == null
          ? const Center(child: Text('로그인이 필요합니다.'))
          : FutureBuilder<DocumentSnapshot>(
              future: _userFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.'));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('사용자 정보를 찾을 수 없습니다.'));
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>;
                if (!_isEditing) {
                  _nicknameController.text = userData['nickname'] ?? '';
                  _ageController.text = userData['age']?.toString() ?? '';
                  _regionController.text = userData['region'] ?? '';
                  _sexController.text = userData['sex'] ?? '';
                  _emailController.text = userData['email'] ?? '';
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundImage: _image != null
                                    ? FileImage(_image!)
                                    : (userData['profileImageUrl'] != null
                                        ? NetworkImage(userData['profileImageUrl'])
                                        : null) as ImageProvider?,
                                child: _image == null && userData['profileImageUrl'] == null
                                    ? const Icon(Icons.person, size: 50)
                                    : null,
                              ),
                              if (_isEditing)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text('이미지 변경', style: TextStyle(color: Colors.blue)),
                                )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildInfoField('닉네임', _nicknameController),
                      _buildInfoField('나이', _ageController, keyboardType: TextInputType.number),
                      _buildInfoField('지역', _regionController),
                      _buildInfoField('성별', _sexController),
                      _buildInfoField('이메일', _emailController, keyboardType: TextInputType.emailAddress),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: _isEditing
          ? TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
              keyboardType: keyboardType,
            )
          : Row(
              children: [
                Text('$label: ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Expanded(child: Text(controller.text, style: const TextStyle(fontSize: 18))),
              ],
            ),
    );
  }
}

