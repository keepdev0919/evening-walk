import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:walk/src/features/walk/presentation/widgets/waypointDialog.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  NotificationService(this.flutterLocalNotificationsPlugin);

  Future<void> initialize(BuildContext context) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
        if (notificationResponse.payload != null) {
          debugPrint('notification payload: ${notificationResponse.payload}');
          WaypointDialogs.showQuestionDialog(context, notificationResponse.payload!); 
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          (NotificationResponse notificationResponse) async {
        if (notificationResponse.payload != null) {
          debugPrint(
              'background notification payload: ${notificationResponse.payload}');
          WaypointDialogs.showQuestionDialog(context, notificationResponse.payload!); 
        }
      },
    );
  }

  Future<void> showWaypointNotification(String questionPayload) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('waypoint_channel_id', '경유지 알림',
            channelDescription: '경유지 도착 시 질문 알림',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false,
            icon: 'ic_walk_notification');
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
      0,
      '경유지 도착!',
      '경유지에 도착했습니다. 질문을 확인하시려면 탭하세요.',
      notificationDetails,
      payload: questionPayload,
    );
  }
}
