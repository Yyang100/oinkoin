// file: edit-record-page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:function_tree/function_tree.dart';
import 'package:piggybank/categories/categories-tab-page-view.dart';
import 'package:piggybank/helpers/alert-dialog-builder.dart';
import 'package:piggybank/helpers/datetime-utility-functions.dart';
import 'package:piggybank/helpers/records-utility-functions.dart';
import 'package:piggybank/i18n.dart';
import 'package:piggybank/models/category-type.dart';
import 'package:piggybank/models/category.dart';
import 'package:piggybank/models/record.dart';
import 'package:piggybank/models/recurrent-period.dart';
import 'package:piggybank/premium/splash-screen.dart';
import 'package:piggybank/premium/util-widgets.dart';
import 'package:piggybank/services/database/database-interface.dart';
import 'package:piggybank/services/service-config.dart';

import '../components/category_icon_circle.dart';
import '../models/recurrent-record-pattern.dart';
import '../settings/constants/preferences-keys.dart';
import '../settings/preferences-utils.dart';

class EditRecordPage extends StatefulWidget {
  final Record? passedRecord;
  final Category? passedCategory;
  final RecurrentRecordPattern? passedReccurrentRecordPattern;
  final bool readOnly;

  EditRecordPage(
      {Key? key,
      this.passedRecord,
      this.passedCategory,
      this.passedReccurrentRecordPattern,
      this.readOnly = false})
      : super(key: key);

  @override
  EditRecordPageState createState() => EditRecordPageState(this.passedRecord,
      this.passedCategory, this.passedReccurrentRecordPattern, this.readOnly);
}

class EditRecordPageState extends State<EditRecordPage> {
  DatabaseInterface database = ServiceConfig.database;
  TextEditingController _textEditingController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Record? record;

  Record? passedRecord;
  Category? passedCategory;
  bool readOnly = false;
  RecurrentRecordPattern? passedReccurrentRecordPattern;

  RecurrentPeriod? recurrentPeriod;
  int? recurrentPeriodIndex;

  late String currency;
  DateTime? lastCharInsertedMillisecond;
  late bool enableRecordNameSuggestions;

  DateTime? localDisplayDate;

  EditRecordPageState(this.passedRecord, this.passedCategory,
      this.passedReccurrentRecordPattern, this.readOnly);

  static final dropDownList = [
    new DropdownMenuItem<int>(
        value: 0,
        child: new Text("Every day".i18n, style: TextStyle(fontSize: 20.0))),
    new DropdownMenuItem<int>(
        value: 1,
        child: new Text("Every week".i18n, style: TextStyle(fontSize: 20.0))),
    new DropdownMenuItem<int>(
        value: 3,
        child:
            new Text("Every two weeks".i18n, style: TextStyle(fontSize: 20.0))),
    new DropdownMenuItem<int>(
      value: 2,
      child: new Text("Every month".i18n, style: TextStyle(fontSize: 20.0)),
    ),
    new DropdownMenuItem<int>(
      value: 4,
      child:
          new Text("Every three months".i18n, style: TextStyle(fontSize: 20.0)),
    ),
    new DropdownMenuItem<int>(
      value: 5,
      child:
          new Text("Every four months".i18n, style: TextStyle(fontSize: 20.0)),
    ),
    new DropdownMenuItem<int>(
      value: 6,
      child: new Text("Every year".i18n, style: TextStyle(fontSize: 20.0)),
    )
  ];

  bool isMathExpression(String text) {
    bool containsOperator = false;
    containsOperator |= text.contains("+");
    containsOperator |= text.contains("-");
    containsOperator |= text.contains("*");
    containsOperator |= text.contains("/");
    containsOperator |= text.contains("%");
    return containsOperator;
  }

  String? tryParseMathExpr(String text) {
    var groupingSeparator = getGroupingSeparator();
    var decimalSeparator = getDecimalSeparator();
    if (isMathExpression(text)) {
      try {
        text = text.replaceAll(groupingSeparator, "");
        text = text.replaceAll(decimalSeparator, ".");
        return text;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  void solveMathExpressionAndUpdateText() {
    var text = _textEditingController.text.toLowerCase();
    var newNum;
    String? mathExpr = tryParseMathExpr(text);
    if (mathExpr != null) {
      try {
        newNum = mathExpr.interpret();
      } catch (e) {
        stderr.writeln("Can't parse the expression: $text");
      }
      if (newNum != null) {
        text = getCurrencyValueString(newNum, turnOffGrouping: true);
        _textEditingController.value = _textEditingController.value.copyWith(
          text: text,
          selection:
              TextSelection(baseOffset: text.length, extentOffset: text.length),
          composing: TextRange.empty,
        );
        changeRecordValue(_textEditingController.text.toLowerCase());
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Loading preferences
    bool overwriteDotValue = getOverwriteDotValue();
    bool overwriteCommaValue = getOverwriteCommaValue();
    enableRecordNameSuggestions = PreferencesUtils.getOrDefault<bool>(
        ServiceConfig.sharedPreferences!,
        PreferencesKeys.enableRecordNameSuggestions)!;

    // Loading parameters passed to the page

    if (passedRecord != null) {
      // I am editing an existing record
      record = passedRecord;
      // Use the localDateTime getter for display purposes
      localDisplayDate = passedRecord!.localDateTime;
      _textEditingController.text =
          getCurrencyValueString(record!.value!.abs(), turnOffGrouping: true);
      if (record!.recurrencePatternId != null) {
        database
            .getRecurrentRecordPattern(record!.recurrencePatternId)
            .then((value) {
          if (value != null) {
            setState(() {
              recurrentPeriod = value.recurrentPeriod;
              recurrentPeriodIndex = value.recurrentPeriod!.index;
            });
          }
        });
      }
    } else if (passedReccurrentRecordPattern != null) {
      // I am editing a recurrent pattern
      // Instantiate a new Record object from the pattern
      record = Record(
        passedReccurrentRecordPattern!.value,
        passedReccurrentRecordPattern!.title,
        passedReccurrentRecordPattern!.category,
        // The record's utcDateTime is from the pattern's utcDateTime
        passedReccurrentRecordPattern!.utcDateTime,
        // The record's timezone name is from the pattern's timezone name
        timeZoneName: passedReccurrentRecordPattern!.timeZoneName,
        description: passedReccurrentRecordPattern!.description,
      );
      // Use the localDateTime for display
      localDisplayDate = passedReccurrentRecordPattern!.localDateTime;

      _textEditingController.text =
          getCurrencyValueString(record!.value!.abs(), turnOffGrouping: true);
      setState(() {
        recurrentPeriod = passedReccurrentRecordPattern!.recurrentPeriod;
        recurrentPeriodIndex =
            passedReccurrentRecordPattern!.recurrentPeriod!.index;
      });
    } else {
      // I am adding a new record
      // Create a new record with a UTC timestamp and the current local timezone
      record = Record(null, null, passedCategory, DateTime.now().toUtc());
      localDisplayDate = record!.localDateTime;
    }

    // Keyboard listeners initializations (the same as before)
    _textEditingController.addListener(() {
      lastCharInsertedMillisecond = DateTime.now();
      var text = _textEditingController.text.toLowerCase();
      final exp = new RegExp(r'[^\d.,\\+\-\*=/%x]');
      text = text.replaceAll("x", "*");
      text = text.replaceAll(exp, "");

      if (overwriteDotValue) {
        text = text.replaceAll(".", ",");
      }

      if (overwriteCommaValue) {
        text = text.replaceAll(",", ".");
      }
      TextSelection previousSelection = _textEditingController.selection;
      _textEditingController.value = _textEditingController.value.copyWith(
        text: text,
        selection: previousSelection,
        composing: TextRange.empty,
      );
    });

    _textEditingController.addListener(() async {
      var text = _textEditingController.text.toLowerCase();
      await Future.delayed(Duration(seconds: 2));
      var textAfterPause = _textEditingController.text.toLowerCase();
      if (text == textAfterPause) {
        solveMathExpressionAndUpdateText();
      }
    });

    String initialValue = record?.title ?? "";
    _typeAheadController.text = initialValue;
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _typeAheadController.dispose();
    super.dispose();
  }

  Widget _createAddNoteCard() {
    if (readOnly && record!.description == null) {
      return Container();
    }
    return Card(
      elevation: 1,
      child: Container(
        padding:
            const EdgeInsets.only(bottom: 40.0, top: 10, right: 10, left: 10),
        child: Semantics(
          identifier: 'note-field',
          child: TextFormField(
              onChanged: (text) {
                setState(() {
                  record!.description = text;
                });
              },
              enabled: !readOnly,
              style: TextStyle(
                  fontSize: 22.0,
                  color: Theme.of(context).colorScheme.onSurface),
              initialValue: record!.description,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText: "Add a note".i18n,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(10),
                  label: Text("Note"))),
        ),
      ),
    );
  }

  final TextEditingController _typeAheadController = TextEditingController();

  Widget _createTitleCard() {
    return Card(
      elevation: 1,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: TypeAheadField<String>(
          controller: _typeAheadController,
          builder: (context, controller, focusNode) {
            return Semantics(
              identifier: 'record-name-field',
              child: TextFormField(
                  enabled: !readOnly,
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (text) {
                    setState(() {
                      record!.title = text;
                    });
                  },
                  style: TextStyle(
                      fontSize: 22.0,
                      color: Theme.of(context).colorScheme.onSurface),
                  maxLines: 1,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: EdgeInsets.all(10),
                      border: InputBorder.none,
                      hintText: record!.category!.name,
                      labelText: "Record name".i18n)),
            );
          },
          suggestionsCallback: (search) {
            if (search.isNotEmpty && enableRecordNameSuggestions) {
              return database.suggestedRecordTitles(
                  search, record!.category!.name!);
            }
            return null;
          },
          itemBuilder: (context, record) {
            return ListTile(
              title: Text(record),
            );
          },
          onSelected: (selectedTitle) => {
            _typeAheadController.text = selectedTitle,
            setState(() {
              record!.title = selectedTitle;
            })
          },
          hideOnEmpty: true,
        ),
      ),
    );
  }

  Widget _createCategoryCard() {
    return Card(
      elevation: 1,
      child: Container(
          padding: const EdgeInsets.all(15),
          child: Column(children: [
            InkWell(
              onTap: () async {
                if (readOnly) {
                  return; // do nothing
                }
                var selectedCategory = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CategoryTabPageView()),
                );
                if (selectedCategory != null) {
                  setState(() {
                    record!.category = selectedCategory;
                    changeRecordValue(_textEditingController.text
                        .toLowerCase()); // Handle sign change
                  });
                }
              },
              child: Semantics(
                identifier: 'category-field',
                child: Row(
                  children: [
                    CategoryIconCircle(
                        iconEmoji: record!.category!.iconEmoji,
                        iconDataFromDefaultIconSet: record!.category!.icon,
                        backgroundColor: record!.category!.color),
                    Container(
                      margin: EdgeInsets.fromLTRB(20, 10, 10, 10),
                      child: Text(
                        record!.category!.name!,
                        style: TextStyle(
                            fontSize: 20,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ])),
    );
  }

  goToPremiumSplashScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PremiumSplashScreen()),
    );
  }

  Widget _createDateAndRepeatCard() {
    return Card(
      elevation: 1,
      child: Container(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Semantics(
                identifier: 'date-field',
                child: InkWell(
                    onTap: () async {
                      if (readOnly) {
                        return; // do nothing!
                      }
                      FocusScope.of(context).unfocus();
                      // Use the localDisplayDate for the initial date
                      DateTime initialDate = localDisplayDate ?? DateTime.now();
                      DateTime? result = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: DateTime(1970),
                          lastDate:
                              DateTime.now().add(new Duration(days: 365)));
                      if (result != null) {
                        setState(() {
                          // Update the localDisplayDate
                          localDisplayDate = result;
                          // Convert the selected local date to a UTC date
                          record!.utcDateTime = result.toUtc();
                          record!.timeZoneName = ServiceConfig.localTimezone;
                        });
                      }
                    },
                    child: Container(
                        margin: EdgeInsets.fromLTRB(10, 10, 0, 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 28,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            Container(
                              margin: EdgeInsets.only(left: 20, right: 20),
                              child: Text(
                                // Use the localDisplayDate for display
                                getDateStr(localDisplayDate),
                                style: TextStyle(
                                    fontSize: 20,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ),
                            )
                          ],
                        ))),
              ),
              Visibility(
                visible: record!.id == null || recurrentPeriod != null,
                child: Column(
                  children: [
                    Divider(
                      indent: 60,
                      thickness: 1,
                    ),
                    Semantics(
                      identifier: 'repeat-field',
                      child: InkWell(
                          child: Container(
                              margin: EdgeInsets.fromLTRB(10, 0, 0, 0),
                              child: Row(
                                children: [
                                  Icon(Icons.repeat,
                                      size: 28,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                  Expanded(
                                    child: Container(
                                      margin:
                                          EdgeInsets.only(left: 15, right: 10),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                              child: new DropdownButton<int>(
                                            iconSize: 0.0,
                                            items: dropDownList,
                                            onChanged: ServiceConfig
                                                        .isPremium &&
                                                    record!.id == null
                                                ? (value) {
                                                    setState(() {
                                                      recurrentPeriodIndex =
                                                          value;
                                                      recurrentPeriod =
                                                          RecurrentPeriod
                                                              .values[value!];
                                                    });
                                                  }
                                                : null,
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                            },
                                            value: recurrentPeriodIndex,
                                            underline: SizedBox(),
                                            isExpanded: true,
                                            hint: recurrentPeriod == null
                                                ? Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 10.0),
                                                    child: Text(
                                                      "Not repeat".i18n,
                                                      style: TextStyle(
                                                          fontSize: 20.0,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant),
                                                    ),
                                                  )
                                                : Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 10.0),
                                                    child: Text(
                                                      recurrentPeriodString(
                                                          recurrentPeriod),
                                                      style: TextStyle(
                                                          fontSize: 20.0),
                                                    ),
                                                  ),
                                          )),
                                          Visibility(
                                            child: getProLabel(
                                                labelFontSize: 12.0),
                                            visible: !ServiceConfig.isPremium,
                                          ),
                                          Visibility(
                                            child: new IconButton(
                                              icon: new Icon(Icons.close,
                                                  size: 28,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface),
                                              onPressed: () {
                                                setState(() {
                                                  recurrentPeriod = null;
                                                  recurrentPeriodIndex = null;
                                                });
                                              },
                                            ),
                                            visible: record!.id == null &&
                                                recurrentPeriod != null,
                                          )
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ))),
                    ),
                  ],
                ),
              )
            ],
          )),
    );
  }

  Widget _createAmountCard() {
    String categorySign =
        record?.category?.categoryType == CategoryType.expense ? "-" : "+";
    return Card(
      elevation: 1,
      child: Container(
          child: IntrinsicHeight(
              child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: EdgeInsets.all(10),
              margin: EdgeInsets.only(left: 10, top: 25),
              child: Text(categorySign,
                  style: TextStyle(fontSize: 32), textAlign: TextAlign.left),
            ),
          ),
          Expanded(
              child: Container(
            padding: EdgeInsets.all(10),
            child: Semantics(
              identifier: 'amount-field',
              child: TextFormField(
                  enabled: !readOnly,
                  controller: _textEditingController,
                  autofocus: record!.value == null,
                  onChanged: (text) {
                    changeRecordValue(text);
                  },
                  validator: (value) {
                    if (value!.isEmpty) {
                      return "Please enter a value".i18n;
                    }
                    var numericValue = tryParseCurrencyString(value);
                    if (numericValue == null) {
                      return "Not a valid format (use for example: %s)"
                          .i18n
                          .fill([
                        getCurrencyValueString(1234.20, turnOffGrouping: true)
                      ]);
                    }
                    return null;
                  },
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 32.0,
                      color: Theme.of(context).colorScheme.onSurface),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: "0",
                      labelText: "Amount".i18n)),
            ),
          ))
        ],
      ))),
    );
  }

  void changeRecordValue(String text) {
    var numericValue = tryParseCurrencyString(text);
    if (numericValue != null) {
      numericValue = numericValue.abs();
      if (record!.category!.categoryType == CategoryType.expense) {
        numericValue = numericValue * -1;
      }
      record!.value = numericValue;
    }
  }

  addOrUpdateRecord() async {
    if (record!.id == null) {
      await database.addRecord(record);
    } else {
      await database.updateRecordById(record!.id, record);
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  recurrentPeriodHasBeenUpdated(RecurrentRecordPattern toSet) {
    bool recurrentPeriodHasChanged = toSet.recurrentPeriod!.index !=
        passedReccurrentRecordPattern!.recurrentPeriod!.index;
    // Compare the UTC timestamps
    bool startingDateHasChanged = toSet.utcDateTime.millisecondsSinceEpoch !=
        passedReccurrentRecordPattern!.utcDateTime.millisecondsSinceEpoch;
    return recurrentPeriodHasChanged || startingDateHasChanged;
  }

  addOrUpdateRecurrentPattern({id}) async {
    // Create a new recurrent pattern from the updated record
    RecurrentRecordPattern recordPattern =
        RecurrentRecordPattern.fromRecord(record!, recurrentPeriod!, id: id);
    if (id != null) {
      if (recurrentPeriodHasBeenUpdated(recordPattern)) {
        await database.deleteFutureRecordsByPatternId(id, record!.utcDateTime);
        await database.deleteRecurrentRecordPatternById(id);
        await database.addRecurrentRecordPattern(recordPattern);
      } else {
        await database.deleteFutureRecordsByPatternId(id, record!.utcDateTime);
        await database.updateRecordPatternById(id, recordPattern);
      }
    } else {
      await database.addRecurrentRecordPattern(recordPattern);
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  AppBar _getAppBar() {
    return AppBar(
        title: Text(
          readOnly ? 'View record'.i18n : 'Edit record'.i18n,
        ),
        actions: <Widget>[
          Visibility(
              visible: (widget.passedRecord != null ||
                      widget.passedReccurrentRecordPattern != null) &&
                  !readOnly,
              child: IconButton(
                  icon: Semantics(
                      identifier: "delete-button",
                      child: const Icon(Icons.delete)),
                  tooltip: 'Delete'.i18n,
                  onPressed: () async {
                    AlertDialogBuilder deleteDialog =
                        AlertDialogBuilder("Critical action".i18n)
                            .addTrueButtonName("Yes".i18n)
                            .addFalseButtonName("No".i18n);
                    if (widget.passedRecord != null) {
                      deleteDialog = deleteDialog.addSubtitle(
                          "Do you really want to delete this record?".i18n);
                    } else {
                      deleteDialog = deleteDialog.addSubtitle(
                          "Do you really want to delete this recurrent record?"
                              .i18n);
                    }
                    var continueDelete = await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return deleteDialog.build(context);
                        });
                    if (continueDelete) {
                      if (widget.passedRecord != null) {
                        await database.deleteRecordById(record!.id);
                      } else {
                        String patternId =
                            widget.passedReccurrentRecordPattern!.id!;
                        // Use the current UTC time when deleting future records
                        await database.deleteFutureRecordsByPatternId(
                            patternId, DateTime.now().toUtc());
                        await database
                            .deleteRecurrentRecordPatternById(patternId);
                      }
                      Navigator.pop(context);
                    }
                  })),
        ]);
  }

  Widget _getForm() {
    return Container(
      margin: EdgeInsets.fromLTRB(10, 10, 10, 80),
      child: Column(
        children: [
          Form(
              key: _formKey,
              child: Container(
                child: Column(children: [
                  _createAmountCard(),
                  _createTitleCard(),
                  _createCategoryCard(),
                  _createDateAndRepeatCard(),
                  _createAddNoteCard(),
                ]),
              ))
        ],
      ),
    );
  }

  isARecurrentPattern() {
    return recurrentPeriod != null && record?.recurrencePatternId == null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _getAppBar(),
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(child: _getForm()),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  if (isARecurrentPattern()) {
                    String? recurrentPatternId;
                    if (passedReccurrentRecordPattern != null) {
                      recurrentPatternId =
                          this.passedReccurrentRecordPattern!.id;
                    }
                    await addOrUpdateRecurrentPattern(
                      id: recurrentPatternId,
                    );
                  } else {
                    await addOrUpdateRecord();
                  }
                }
              },
              tooltip: 'Save'.i18n,
              child: Semantics(
                  identifier: 'save-button', child: const Icon(Icons.save)),
            ),
    );
  }
}
