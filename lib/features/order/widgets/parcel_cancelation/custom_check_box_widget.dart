import 'package:flutter/material.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class CustomCheckBoxWidget extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onClick;
  const CustomCheckBoxWidget({super.key, required this.title, required this.value, required this.onClick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onClick(!value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: value ? Theme.of(context).primaryColor.withOpacity(0.05) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value ? Theme.of(context).primaryColor : Theme.of(context).disabledColor.withOpacity(0.2),
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Expanded(child: Text(title, style: robotoRegular.copyWith(
            color: value ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.8),
            fontWeight: value ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ))),
          if (value)
            Icon(Icons.check_circle, color: Theme.of(context).primaryColor, size: 22)
          else
            Icon(Icons.radio_button_unchecked, color: Theme.of(context).disabledColor.withOpacity(0.5), size: 22),
        ]),
      ),
    );
  }
}
