import 'package:flutter/material.dart';

/// Maps the symbolic icon names used in `assets/data/azkar.json` onto Material
/// icons, so the data asset stays free of Flutter-specific identifiers.
IconData azkarIcon(String name) => switch (name) {
  'sunrise' => Icons.wb_twilight_rounded,
  'sunset' => Icons.nights_stay_rounded,
  'mosque' => Icons.mosque_rounded,
  'moon' => Icons.dark_mode_rounded,
  'door' => Icons.meeting_room_rounded,
  'beads' => Icons.blur_circular_rounded,
  'hands' => Icons.volunteer_activism_rounded,
  'book' => Icons.menu_book_rounded,
  _ => Icons.auto_awesome_rounded,
};
