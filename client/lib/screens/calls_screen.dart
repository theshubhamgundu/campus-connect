import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Call {
  final String id;
  final String name;
  final String avatar;
  final DateTime time;
  final bool isIncoming;
  final bool isVideo;
  final bool isMissed;

  Call({
    required this.id,
    required this.name,
    required this.avatar,
    required this.time,
    this.isIncoming = true,
    this.isVideo = false,
    this.isMissed = false,
  });
}

class CallsScreen extends StatelessWidget {
  const CallsScreen({Key? key}) : super(key: key);

  // This would normally come from your data source
  final List<Call> calls = const [
    Call(
      id: '1',
      name: 'John Doe',
      avatar: 'assets/images/avatar1.png',
      time: DateTime.now().subtract(const Duration(minutes: 30)),
      isIncoming: true,
      isVideo: false,
      isMissed: true,
    ),
    Call(
      id: '2',
      name: 'Jane Smith',
      avatar: 'assets/images/avatar2.png',
      time: DateTime.now().subtract(const Duration(hours: 2)),
      isIncoming: false,
      isVideo: true,
      isMissed: false,
    ),
    // Add more dummy data as needed
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: calls.length,
      itemBuilder: (context, index) {
        final call = calls[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 25,
            backgroundImage: AssetImage(call.avatar),
            child: call.avatar.isEmpty ? Text(call.name[0]) : null,
          ),
          title: Text(
            call.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Row(
            children: [
              Icon(
                call.isIncoming
                    ? call.isMissed
                        ? Icons.call_missed
                        : Icons.call_received
                    : Icons.call_made,
                size: 16,
                color: call.isMissed ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 4),
              Text(DateFormat('MMM d, h:mm a').format(call.time)),
            ],
          ),
          trailing: IconButton(
            icon: Icon(
              call.isVideo ? Icons.videocam : Icons.call,
              color: const Color(0xFF128C7E),
            ),
            onPressed: () {
              // TODO: Implement call
            },
          ),
          onTap: () {
            // TODO: Show call details
          },
        );
      },
    );
  }
}
