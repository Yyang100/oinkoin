import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:piggybank/i18n.dart';

import '../../components/year-picker.dart' as yp;
import '../../helpers/datetime-utility-functions.dart';
import '../../helpers/records-utility-functions.dart';
import '../../models/record.dart';
import '../../premium/splash-screen.dart';
import '../../services/service-config.dart';
import '../controllers/tab_records_controller.dart';

class TabRecordsDatePicker extends StatelessWidget {
  final TabRecordsController controller;
  final VoidCallback onDateSelected;

  const TabRecordsDatePicker({
    Key? key,
    required this.controller,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var isDarkMode = Theme.of(context).brightness == Brightness.dark;
    var boxBackgroundColor = isDarkMode
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.secondary;

    return SimpleDialog(
      title: Text('Shows records per'.i18n),
      children: <Widget>[
        _buildDialogOption(
          context,
          title: "Month".i18n,
          icon: FontAwesomeIcons.calendarDays,
          color: boxBackgroundColor,
          onPressed: () => _pickMonth(context),
        ),
        _buildDialogOption(
          context,
          title: "Year".i18n,
          subtitle:
              !ServiceConfig.isPremium ? "Available on Oinkoin Pro".i18n : null,
          icon: FontAwesomeIcons.calendarDay,
          color: boxBackgroundColor,
          enabled: ServiceConfig.isPremium,
          onPressed: ServiceConfig.isPremium
              ? () => _pickYear(context)
              : () => _goToPremiumSplashScreen(context),
        ),
        _buildDialogOption(
          context,
          title: "Date Range".i18n,
          subtitle:
              !ServiceConfig.isPremium ? "Available on Oinkoin Pro".i18n : null,
          icon: FontAwesomeIcons.calendarWeek,
          color: boxBackgroundColor,
          enabled: ServiceConfig.isPremium,
          onPressed: ServiceConfig.isPremium
              ? () => _pickDateRange(context)
              : () => _goToPremiumSplashScreen(context),
        ),
        if (controller.customIntervalFrom != null)
          _buildDialogOption(
            context,
            title: "Reset to default dates".i18n,
            icon: FontAwesomeIcons.calendarXmark,
            color: boxBackgroundColor,
            onPressed: () => _resetToDefault(context),
          ),
      ],
    );
  }

  Widget _buildDialogOption(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool enabled = true,
  }) {
    return SimpleDialogOption(
      onPressed: onPressed,
      child: ListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        enabled: enabled,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _pickMonth(BuildContext context) async {
    DateTime? currentDate = controller.customIntervalFrom ?? DateTime.now();
    int currentYear = DateTime.now().year;

    DateTime? dateTime = await showMonthPicker(
      context: context,
      lastDate: DateTime(currentYear + 1, 12),
      initialDate: currentDate,
    );

    if (dateTime != null) {
      DateTime from = DateTime(dateTime.year, dateTime.month, 1);
      DateTime to = getEndOfMonth(dateTime.year, dateTime.month);
      String header = getMonthStr(dateTime);

      var newRecords = await getRecordsByMonth(
          controller.database, dateTime.year, dateTime.month);

      updateAndClose(context, newRecords, from, to, header);
    }
  }

  Future<void> _pickYear(BuildContext context) async {
    DateTime currentDate = DateTime.now();
    DateTime initialDate = DateTime(currentDate.year, 1);
    DateTime lastDate = DateTime(currentDate.year + 1, 1);
    DateTime firstDate = DateTime(1950, currentDate.month);

    DateTime? yearPicked = await yp.showYearPicker(
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
      context: context,
    );

    if (yearPicked != null) {
      DateTime from = DateTime(yearPicked.year, 1, 1);
      DateTime to = DateTime(yearPicked.year, 12, 31, 23, 59);
      String header = getYearStr(from);

      var newRecords =
          await getRecordsByYear(controller.database, yearPicked.year);

      updateAndClose(context, newRecords, from, to, header);
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    DateTime currentDate = DateTime.now();
    DateTime lastDate = DateTime(currentDate.year + 1, currentDate.month + 1);
    DateTime firstDate = DateTime(currentDate.year - 5, currentDate.month);
    DateTimeRange initialDateTimeRange = DateTimeRange(
      start: DateTime.now().subtract(Duration(days: 7)),
      end: currentDate,
    );

    DateTimeRange? dateTimeRange = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialDateTimeRange,
      locale: I18n.locale,
    );

    if (dateTimeRange != null) {
      DateTime from = DateTime(
        dateTimeRange.start.year,
        dateTimeRange.start.month,
        dateTimeRange.start.day,
      );
      DateTime to = DateTime(
        dateTimeRange.end.year,
        dateTimeRange.end.month,
        dateTimeRange.end.day,
        23,
        59,
      );
      String header = getDateRangeStr(from, to);

      var newRecords =
          await getRecordsByInterval(controller.database, from, to);

      updateAndClose(context, newRecords, from, to, header);
    }
  }

  void updateAndClose(BuildContext context, List<Record?> newRecords,
      DateTime from, DateTime to, String header) {
    controller.records = newRecords;
    controller.updateCustomInterval(from, to, header);
    controller.filterRecords();
    controller.onStateChanged();
    onDateSelected();
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _resetToDefault(BuildContext context) async {
    controller.customIntervalFrom = null;
    controller.customIntervalTo = null;
    await controller.updateRecurrentRecordsAndFetchRecords();
    controller.onStateChanged();
    onDateSelected();
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _goToPremiumSplashScreen(BuildContext context) async {
    Navigator.of(context, rootNavigator: true).pop('dialog');
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PremiumSplashScreen()),
    );
  }
}
