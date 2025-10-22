import 'package:flutter/material.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMyStatus(),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Recent updates',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) {
              return _buildStatusItem(
                name: 'Contact ${index + 1}',
                time: '${index + 1}h ago',
                hasUnseen: index % 3 == 0,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMyStatus() {
    return ListTile(
      leading: Stack(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.person, size: 30, color: Colors.white),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
      title: const Text(
        'My status',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text('Tap to add status update'),
      onTap: () {
        // TODO: Implement add status
      },
    );
  }

  Widget _buildStatusItem({
    required String name,
    required String time,
    bool hasUnseen = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: hasUnseen ? Colors.green : Colors.grey,
            width: 2,
          ),
        ),
        child: CircleAvatar(
          radius: 26,
          backgroundColor: Colors.grey[300],
          child: Text(
            name[0],
            style: const TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(time),
      onTap: () {
        // TODO: Implement view status
      },
    );
  }
}
