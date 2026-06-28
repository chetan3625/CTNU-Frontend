import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

/// WhatsApp-style emoji panel shown below the chat input bar.
class ChatEmojiPicker extends StatelessWidget {
  final TextEditingController textController;
  final ScrollController scrollController;
  final VoidCallback? onEmojiSelected;

  const ChatEmojiPicker({
    super.key,
    required this.textController,
    required this.scrollController,
    this.onEmojiSelected,
  });

  @override
  Widget build(BuildContext context) {
    return EmojiPicker(
      textEditingController: textController,
      scrollController: scrollController,
      onEmojiSelected: (category, emoji) => onEmojiSelected?.call(),
      config: Config(
        height: 280,
        checkPlatformCompatibility: true,
        viewOrderConfig: const ViewOrderConfig(
          top: EmojiPickerItem.searchBar,
          middle: EmojiPickerItem.emojiView,
          bottom: EmojiPickerItem.categoryBar,
        ),
        emojiViewConfig: const EmojiViewConfig(
          backgroundColor: Color(0xFF121212),
          columns: 8,
          emojiSizeMax: 28,
        ),
        skinToneConfig: const SkinToneConfig(),
        categoryViewConfig: CategoryViewConfig(
          backgroundColor: const Color(0xFF1F1F1F),
          dividerColor: const Color(0xFF2C2C2C),
          indicatorColor: const Color(0xFF6C63FF),
          iconColor: Colors.white38,
          iconColorSelected: Color(0xFF6C63FF),
          categoryIcons: const CategoryIcons(
            recentIcon: Icons.access_time_outlined,
            smileyIcon: Icons.emoji_emotions_outlined,
            animalIcon: Icons.pets_outlined,
            foodIcon: Icons.restaurant_outlined,
            activityIcon: Icons.sports_soccer_outlined,
            travelIcon: Icons.directions_car_outlined,
            objectIcon: Icons.lightbulb_outline,
            symbolIcon: Icons.emoji_symbols_outlined,
            flagIcon: Icons.flag_outlined,
          ),
        ),
        bottomActionBarConfig: const BottomActionBarConfig(
          backgroundColor: Color(0xFF1F1F1F),
          buttonColor: Color(0xFF1F1F1F),
          buttonIconColor: Colors.white54,
        ),
        searchViewConfig: const SearchViewConfig(
          backgroundColor: Color(0xFF1F1F1F),
          buttonIconColor: Colors.white54,
          hintText: 'Search emoji',
        ),
      ),
    );
  }
}
