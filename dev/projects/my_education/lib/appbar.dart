import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int currentIndex;
  final Function(int) onTabTapped;
  final VoidCallback onSearchPressed;

  const CustomAppBar({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
    required this.onSearchPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: LayoutBuilder(
        builder: (context, constraints) {
          // Define the width threshold at which to change layout
          bool isNarrow = constraints.maxWidth < 400; // Adjust as necessary

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 10),
              // Text buttons inside Expanded to avoid overflow
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Primary Level Tab
                    TextButton(
                      onPressed: () => onTabTapped(0),
                      child: Text(
                        'Primary level',
                        style: TextStyle(
                          fontSize: isNarrow
                              ? 10
                              : 12, // Adjust font size on narrow screens
                          color: currentIndex == 0
                              ? const Color(0xFF1F42FF)
                              : Colors.black,
                          decoration: currentIndex == 0
                              ? TextDecoration.underline
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Secondary Level Tab
                    TextButton(
                      onPressed: () => onTabTapped(1),
                      child: Text(
                        'Secondary level',
                        style: TextStyle(
                          fontSize: isNarrow
                              ? 10
                              : 12, // Adjust font size on narrow screens
                          color: currentIndex == 1
                              ? const Color(0xFF1F42FF)
                              : Colors.black,
                          decoration: currentIndex == 1
                              ? TextDecoration.underline
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black),
          onPressed: () {
            onSearchPressed();
          },
        ),
      ],
    );
  }
}
