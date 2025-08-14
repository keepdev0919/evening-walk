import 'package:flutter_email_sender/flutter_email_sender.dart';

class EmailWidget {
  void sendEmail() async {
    final Email email = Email(
      body: '',
      subject: '[저녁산책 문의]',
      recipients: const ['keepdev0919@gmail.com'],
      cc: [],
      bcc: [],
      attachmentPaths: [],
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (error) {}
  }
}
