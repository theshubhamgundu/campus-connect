import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class FilePickerButton extends StatelessWidget {
  final Function(File file, String mimeType) onFileSelected;
  final bool isImageOnly;
  final String? dialogTitle;
  final IconData? icon;
  final String? tooltip;

  const FilePickerButton({
    Key? key,
    required this.onFileSelected,
    this.isImageOnly = false,
    this.dialogTitle,
    this.icon,
    this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      icon: Icon(icon ?? Icons.attach_file),
      onPressed: () => _showPickerOptions(context),
      tooltip: tooltip ?? 'Attach file',
    );

    return tooltip != null
        ? Tooltip(
            message: tooltip!,
            child: button,
          )
        : button;
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!isImageOnly) ...[
                _buildListTile(
                  context,
                  icon: Icons.insert_drive_file,
                  title: 'Document',
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocument();
                  },
                ),
                const Divider(height: 1),
              ],
              _buildListTile(
                context,
                icon: Icons.photo_library,
                title: 'Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const Divider(height: 1),
              _buildListTile(
                context,
                icon: Icons.camera_alt,
                title: 'Camera',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: isImageOnly
            ? ['jpg', 'jpeg', 'png', 'gif', 'webp']
            : [
                'pdf',
                'doc',
                'docx',
                'xls',
                'xlsx',
                'ppt',
                'pptx',
                'txt',
                'jpg',
                'jpeg',
                'png',
                'gif',
                'webp',
                'mp4',
                'mov',
              ],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
        onFileSelected(file, mimeType);
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
        onFileSelected(file, mimeType);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }
}
