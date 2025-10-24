import 'package:flutter/material.dart';

class PlaceholderImage extends StatelessWidget {
  final String? assetPath;
  final double width;
  final double height;
  final String placeholderText;
  final Color backgroundColor;
  final Color textColor;

  const PlaceholderImage({
    Key? key,
    this.assetPath,
    this.width = 100,
    this.height = 100,
    this.placeholderText = 'Image',
    this.backgroundColor = Colors.grey,
    this.textColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: backgroundColor.withOpacity(0.2),
      alignment: Alignment.center,
      child: assetPath != null
          ? Image.asset(
              assetPath!,
              width: width,
              height: height,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Text(
          placeholderText,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
