import 'package:flutter/material.dart';
import 'common_arrival_dialog.dart';

class DestinationDialog {
  static Future<bool?> showDestinationArrivalDialog({
    required BuildContext context,
  }) {
    return CommonArrivalDialog.show<bool>(
      context: context,
      title: '목적지 도착!',
      icon: Icons.flag,
      iconColor: Colors.red,
      message: '목적지 이벤트를 확인하시겠어요?',
      onEventConfirm: () {
        // CommonArrivalDialog에서 true를 반환하고 pop 처리됨
      },
      onLater: () {
        // CommonArrivalDialog에서 false를 반환하고 pop 처리됨
      },
      barrierDismissible: false,
    );
  }
}
