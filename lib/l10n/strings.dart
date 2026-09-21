import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/membership.dart';
import '../utils/bangla_utils.dart';
import 'locale_provider.dart';

/// Every user-facing string in the app, in Bangla and English. Screens read
/// via `Strings.of(context)` (rebuilds on language change through
/// [LocaleProvider]) and pick a getter per piece of text — no ARB/codegen,
/// just a plain class, so adding a string is "add a getter here".
class Strings {
  final AppLanguage lang;
  const Strings(this.lang);

  static Strings of(BuildContext context) {
    final language = context.watch<LocaleProvider>().language;
    return Strings(language);
  }

  bool get _bn => lang == AppLanguage.bn;
  String _t(String bn, String en) => _bn ? bn : en;

  // ---- Common / shared ----
  String get appTitle => _t('বাইতুলমাল কালেকশন ট্র্যাকার', 'Baytulmal Collection Tracker');
  String get cancel => _t('বাতিল', 'Cancel');
  String get save => _t('সংরক্ষণ করুন', 'Save');
  String get delete => _t('মুছে ফেলুন', 'Delete');
  String get edit => _t('সম্পাদনা', 'Edit');
  String get rename => _t('নাম সম্পাদনা', 'Rename');
  String get name => _t('নাম', 'Name');
  String get ok => _t('ঠিক আছে', 'OK');
  String get confirm => _t('নিশ্চিত করুন', 'Confirm');
  String get required => _t('আবশ্যক', 'Required');
  String get optional => _t('ঐচ্ছিক', 'Optional');
  String get enterValidNumber => _t('সঠিক সংখ্যা দিন', 'Enter a valid number');
  String get negativeNotAllowed => _t('ঋণাত্মক মান গ্রহণযোগ্য নয়', 'Negative values are not allowed');
  String get retry => _t('আবার চেষ্টা করুন', 'Retry');
  String get loading => _t('লোড হচ্ছে...', 'Loading...');
  String get nameRequired => _t('নাম আবশ্যক', 'Name is required');

  // ---- screens/protisthan_list_screen.dart (home) ----
  String get homeDataManagementTooltip => _t('ডেটা ব্যবস্থাপনা (এক্সপোর্ট/ইমপোর্ট)', 'Data management (export/import)');
  String get homeAccountTooltip => _t('আমার অ্যাকাউন্ট', 'My account');
  String get homeEmptyMessage =>
      _t('কোনো থানা যোগ করা হয়নি।\nনিচের + বোতাম চেপে একটি থানা যোগ করুন।', 'No থানা added yet.\nTap the + button below to add one.');
  String homeWardCriteriaCount(int wardCount, int criteriaCount) {
    final w = BanglaMonths.toBanglaDigits(wardCount);
    final c = BanglaMonths.toBanglaDigits(criteriaCount);
    return _t('$wটি ওয়ার্ড · $cটি খাত', '$w ward(s) · $c criteria');
  }
  String get homeMembersMenuItem => _t('সদস্য ব্যবস্থাপনা', 'Member management');
  String get homeAddProtisthanTitle => _t('নতুন থানা যোগ করুন', 'Add new থানা');
  String get homeEditProtisthanTitle => _t('থানার নাম সম্পাদনা', 'Edit থানা name');
  String get homeDeleteProtisthanTitle => _t('থানা মুছে ফেলুন?', 'Delete থানা?');
  String homeDeleteProtisthanMessage(String name) => _t(
        '"$name" মুছে ফেললে এর সকল ওয়ার্ড, খাত এবং এন্ট্রি ডেটাও স্থায়ীভাবে মুছে যাবে। '
            'এই কাজটি ফিরিয়ে নেওয়া যাবে না।',
        'Deleting "$name" will also permanently delete all its wards, criteria, '
            'and entry data. This cannot be undone.',
      );

  // ---- screens/protisthan_detail_screen.dart ----
  String get detailTabWards => _t('ওয়ার্ড সমূহ', 'Wards');
  String get detailTabCriteria => _t('খাত', 'Criteria');
  String get detailTabReport => _t('রিপোর্ট', 'Report');

  String get addWardTitle => _t('নতুন ওয়ার্ড যোগ করুন', 'Add new ward');
  String get editWardTitle => _t('ওয়ার্ড সম্পাদনা', 'Edit ward');
  String get deleteWardTitle => _t('ওয়ার্ড মুছে ফেলুন?', 'Delete ward?');
  String deleteWardMessage(String name) => _t(
        '"$name" মুছে ফেললে এর সকল এন্ট্রি ডেটাও স্থায়ীভাবে মুছে যাবে।',
        'Deleting "$name" will also permanently delete all its entry data.',
      );
  String get emptyWardsMessage =>
      _t('কোনো ওয়ার্ড যোগ করা হয়নি।\nনিচের + বোতাম চেপে একটি ওয়ার্ড যোগ করুন।', 'No wards added yet.\nTap the + button below to add one.');
  String get wardEmptyAmount => _t('৳ ০ (খালি)', '৳ 0 (empty)');
  String nisabPrefix(String amount) => _t('ধার্যকৃত নিসাব $amount', 'Target নিসাব $amount');
  String get wardMenuManageAll => _t('সব ওয়ার্ড ম্যানেজ করুন', 'Manage all wards');

  String criteriaCountLabel(int count) {
    final c = BanglaMonths.toBanglaDigits(count);
    return _t('$cটি খাত নির্ধারিত আছে', '$c criteria defined');
  }

  String get criteriaSameListNote =>
      _t('এই থানার সকল ওয়ার্ডের জন্য একই খাত তালিকা ব্যবহৃত হয়।', 'The same criteria list is used for every ward in this থানা.');
  String get manageCriteriaButton => _t('খাত ম্যানেজ করুন', 'Manage criteria');

  String get thanaIncomeTitle => _t('থানার আয়', "থানা's income");
  String get thanaIncomeSubtitle => _t('থানার নিজস্ব কালেকশন, খাত অনুযায়ী', "থানা's own collection, by criteria");
  String get remittanceCardTitle => _t('থানার বাস্তব জমা খরচ', "থানা's actual deposit & expense");
  String get remittanceCardSubtitle =>
      _t('সব ওয়ার্ডের বাস্তব জমা ও থানার ব্যয়ের হিসাব', "All wards' actual deposit and থানা's expense");
  String get matrixCardTitle => _t('ম্যাট্রিক্স রিপোর্ট', 'Matrix report');
  String get matrixCardSubtitle => _t('ওয়ার্ড × খাত টেবিল — PDF/Excel এক্সপোর্ট করুন', 'Ward × criteria table — export PDF/Excel');
  String get summaryCardTitle => _t('থানার মাসিক কালেকশন এক নজরে', "থানা's monthly collection at a glance");
  String get summaryCardSubtitle => _t('মোট কালেকশন, খাত ও ওয়ার্ড অনুযায়ী বিভাজন', 'Total collection, broken down by criteria and ward');
  String get trendCardTitle => _t('ট্রেন্ড / তুলনা', 'Trend / compare');
  String get trendCardSubtitle => _t('একাধিক মাসের কালেকশন গ্রাফ আকারে তুলনা করুন', 'Compare collection across months as a graph');

  // ---- screens/ward_management_screen.dart ----
  String wardManagementTitle(String protisthanName) => _t('ওয়ার্ড সমূহ ($protisthanName)', 'Wards ($protisthanName)');
  String wardNisabLine(String amount) => _t('ধার্যকৃত নিসাব: $amount', 'Target নিসাব: $amount');

  // ---- screens/criteria_management_screen.dart ----
  String criteriaManagementTitle(String protisthanName) => _t('খাত ($protisthanName)', 'Criteria ($protisthanName)');
  String get addCriteriaTitle => _t('নতুন খাত যোগ করুন', 'Add new criteria');
  String get criteriaNameLabel => _t('খাতের নাম', 'Criteria name');
  String get criteriaNameHint => _t('যেমনঃ দোকান ভাড়া', 'e.g. Shop rent');
  String get editCriteriaTitle => _t('খাতের নাম সম্পাদনা', 'Edit criteria name');
  String get deleteCriteriaTitle => _t('খাত মুছে ফেলুন?', 'Delete criteria?');
  String deleteCriteriaMessage(String name) => _t(
        '"$name" মুছে ফেললে সকল ওয়ার্ডের এই খাত সংক্রান্ত এন্ট্রি ডেটাও মুছে যাবে।',
        'Deleting "$name" will also delete its entry data across every ward.',
      );
  String get emptyCriteriaMessage =>
      _t('কোনো খাত যোগ করা হয়নি।\nনিচের + বোতাম চেপে একটি খাত যোগ করুন।', 'No criteria added yet.\nTap the + button below to add one.');
  String get specialCriteriaNote =>
      _t('বিশেষ খাত — ধার্যকৃত নিসাবের সাথে সম্পর্কিত', 'Special criteria — related to the target নিসাব');

  // ---- screens/member_management_screen.dart ----
  String memberManagementTitle(String protisthanName) => _t('সদস্য ($protisthanName)', 'Members ($protisthanName)');
  String get emptyMembersMessage => _t('কোনো সদস্য পাওয়া যায়নি।', 'No members found.');
  String get memberNoUserFound => _t(
        'এই ইমেইলে কোনো ব্যবহারকারী পাওয়া যায়নি — তাকে আগে একবার অ্যাপে সাইন-ইন করতে হবে।',
        'No user found with this email — they need to sign in to the app at least once first.',
      );
  String get memberAdded => _t('সদস্য যোগ করা হয়েছে', 'Member added');
  String get addMemberTitle => _t('নতুন সদস্য যোগ করুন', 'Add new member');
  String get memberEmailLabel => _t('ইমেইল', 'Email');
  String get memberRoleLabel => _t('রোল', 'Role');
  String get addButton => _t('যোগ করুন', 'Add');
  String memberChangeRoleTitle(String who) => _t('$who — রোল পরিবর্তন', '$who — Change role');
  String get memberRemoveTitle => _t('সদস্য বাদ দেবেন?', 'Remove member?');
  String memberRemoveMessage(String who) => _t(
        '"$who" কে এই থানা থেকে বাদ দিলে তার আর এই থানায় প্রবেশাধিকার থাকবে না।',
        'Removing "$who" from this থানা will revoke their access to it.',
      );
  String get memberChangeRoleMenuItem => _t('রোল পরিবর্তন', 'Change role');
  String get memberRemoveMenuItem => _t('বাদ দিন', 'Remove');

  String roleLabel(ProtisthanRole role) {
    switch (role) {
      case ProtisthanRole.creator:
        return _t('নির্মাতা', 'Creator');
      case ProtisthanRole.admin:
        return _t('অ্যাডমিন', 'Admin');
      case ProtisthanRole.collector:
        return _t('কালেক্টর', 'Collector');
      case ProtisthanRole.member:
        return _t('সদস্য', 'Member');
    }
  }

  // ---- screens/data_management_screen.dart ----
  String get dataManagementTitle => _t('ডেটা ব্যবস্থাপনা', 'Data management');
  String get dataExportingStatus => _t('ব্যাকআপ ফাইল তৈরি হচ্ছে...', 'Creating backup file...');
  String get dataExportDone => _t('ব্যাকআপ ফাইল তৈরি হয়েছে', 'Backup file created');
  String dataExportFailed(String error) => _t('এক্সপোর্ট ব্যর্থ হয়েছে: $error', 'Export failed: $error');
  String get dataReadingStatus => _t('ব্যাকআপ ফাইল পড়া ও যাচাই করা হচ্ছে...', 'Reading and validating backup file...');
  String get dataReplaceTitle => _t('বিদ্যমান ডেটা প্রতিস্থাপন করা হবে', 'Existing data will be replaced');
  String dataReplaceMessage(int protisthanCount, int wardCount, int criteriaCount, int entryCount) {
    final p = BanglaMonths.toBanglaDigits(protisthanCount);
    final w = BanglaMonths.toBanglaDigits(wardCount);
    final c = BanglaMonths.toBanglaDigits(criteriaCount);
    final e = BanglaMonths.toBanglaDigits(entryCount);
    return _t(
      'এই ব্যাকআপ ফাইলে $pটি থানা, $wটি ওয়ার্ড, $cটি খাত এবং $eটি এন্ট্রি আছে।\n\n'
          'ইমপোর্ট করলে অ্যাপে বর্তমানে থাকা সকল ডেটা মুছে গিয়ে এই ব্যাকআপ দিয়ে প্রতিস্থাপিত হবে। '
          'এই কাজটি ফিরিয়ে নেওয়া যাবে না।',
      'This backup file has $p থানা, $w wards, $c criteria, and $e entries.\n\n'
          "Importing will delete all of the app's current data and replace it "
          'with this backup. This cannot be undone.',
    );
  }

  String get dataReplaceButton => _t('প্রতিস্থাপন করুন', 'Replace');
  String get dataRestoringLocalStatus => _t('স্থানীয়ভাবে প্রতিস্থাপন করা হচ্ছে...', 'Restoring locally...');
  String get dataSyncingCloudStatus => _t('ক্লাউডে সিঙ্ক করা হচ্ছে...', 'Syncing to cloud...');
  String get dataImportDone => _t('ডেটা সফলভাবে ইমপোর্ট করা হয়েছে', 'Data imported successfully');
  String dataImportFailed(String error) => _t('ইমপোর্ট ব্যর্থ হয়েছে: $error', 'Import failed: $error');

  String get dataExportCardTitle => _t('ডেটা এক্সপোর্ট (Backup)', 'Data export (Backup)');
  String get dataExportCardBody => _t(
        'সকল থানা, ওয়ার্ড, খাত ও এন্ট্রি ডেটা একটি JSON ফাইলে সংরক্ষণ করুন। '
            'ফাইলটি শেয়ার করে অন্য ডিভাইসে বা নিরাপদ স্থানে রাখতে পারবেন।',
        'Save all থানা, ward, criteria, and entry data to a JSON file. Share '
            'the file to another device or keep it somewhere safe.',
      );
  String get dataExportButton => _t('ডেটা এক্সপোর্ট করুন', 'Export data');
  String get dataImportCardTitle => _t('ডেটা ইমপোর্ট (Restore)', 'Data import (Restore)');
  String get dataImportCardBody => _t(
        'পূর্বে এক্সপোর্ট করা একটি ব্যাকআপ (.json) ফাইল থেকে ডেটা ফিরিয়ে আনুন। '
            'এটি অ্যাপের বর্তমান সকল ডেটা মুছে ব্যাকআপ দিয়ে প্রতিস্থাপন করবে। '
            'ব্যাকআপের থানা যদি ক্লাউডে আগে থেকে না থাকে, ইমপোর্টের পর আপনি সাইন-ইন '
            'থাকলে সেটি স্বয়ংক্রিয়ভাবে ক্লাউডে আপলোড হয়ে আপনি তার নির্মাতা হয়ে যাবেন।',
        'Restore data from a previously exported backup (.json) file. This '
            "will delete the app's current data and replace it with the "
            "backup. If the backup's থানা doesn't already exist in the "
            'cloud, it will be uploaded automatically and you will become its '
            'creator, provided you are signed in after importing.',
      );
  String get dataImportButton => _t('ব্যাকআপ ফাইল বেছে নিন', 'Choose backup file');

  // ---- services/backup_service.dart ----
  String get backupShareText => _t('বাইতুলমাল কালেকশন ট্র্যাকার — ডেটা ব্যাকআপ', 'Baytulmal Collection Tracker — Data backup');
  String get backupInvalidJson => _t('এটি একটি বৈধ JSON ফাইল নয়।', 'This is not a valid JSON file.');
  String get backupInvalidFile => _t('এটি একটি বৈধ বাইতুলমাল ব্যাকআপ ফাইল নয়।', 'This is not a valid Baytulmal backup file.');
  String backupMissingList(String key) =>
      _t('ব্যাকআপ ফাইলের গঠন সঠিক নয় — "$key" তালিকা পাওয়া যায়নি।', 'Invalid backup file structure — "$key" list not found.');
  String backupInvalidRow(String table) =>
      _t('ব্যাকআপ ফাইলের "$table" তালিকায় অবৈধ সারি আছে।', 'The backup file\'s "$table" list contains an invalid row.');
  String backupMissingField(String table, String field) => _t(
        'ব্যাকআপ ফাইলের "$table" টেবিলে "$field" ফিল্ড অনুপস্থিত।',
        'The backup file\'s "$table" table is missing the "$field" field.',
      );
  String backupInvalidUuid(String table) =>
      _t('ব্যাকআপ ফাইলের "$table" টেবিলে অবৈধ uuid আছে।', 'The backup file\'s "$table" table has an invalid uuid.');
  String backupDanglingReference(String table, String field) => _t(
        'ব্যাকআপ ফাইলের "$table" টেবিলে একটি সারি অস্তিত্বহীন "$field" নির্দেশ করছে।',
        'A row in the backup file\'s "$table" table references a non-existent "$field".',
      );

  // ---- screens/entry_form_screen.dart ----
  String entryFormTitle(String wardName) => _t('$wardName — এন্ট্রি', '$wardName — Entry');
  String get wardSummaryTooltip => _t('ওয়ার্ড সামারি দেখুন', 'View ward summary');
  String get entrySaved => _t('এন্ট্রি সংরক্ষণ করা হয়েছে', 'Entry saved');
  String get amountFieldHint => _t('খালি', 'Empty');
  String amountFieldLabel(String criteriaName) => _t('$criteriaName (৳)', '$criteriaName (৳)');
  String get selectMonth => _t('মাস নির্বাচন করুন', 'Select month');
  String get incomeExpenseTitle => _t('আয় ও ব্যয়', 'Income & expense');
  String nisabLine(String amount) => _t('ধার্যকৃত নিসাব: $amount', 'Target নিসাব: $amount');
  String actualDepositNoTarget(String amount) =>
      _t('বাস্তব জমা (আয় − ব্যয়) = $amount', 'Actual deposit (income − expense) = $amount');
  String actualDepositMatched(String amount) => _t(
        'বাস্তব জমা (আয় − ব্যয়) = $amount — ধার্যকৃত নিসাবের সাথে মিলেছে',
        'Actual deposit (income − expense) = $amount — matches the target নিসাব',
      );
  String actualDepositMismatch(String amount, String target) => _t(
        'বাস্তব জমা (আয় − ব্যয়) = $amount — ধার্যকৃত নিসাব $target',
        'Actual deposit (income − expense) = $amount — target নিসাব $target',
      );
  String get otherCriteriaTitle => _t('অন্যান্য খাত (সবগুলো ঐচ্ছিক)', 'Other criteria (all optional)');
  String get noExtraCriteriaMessage => _t('এই থানার জন্য অতিরিক্ত কোনো খাত নেই।', 'No extra criteria for this থানা.');

  // ---- screens/thana_income_screen.dart ----
  String get incomeLabel => _t('আয়', 'Income');
  String actualDepositIncomeOnlyNoTarget(String amount) =>
      _t('বাস্তব জমা (আয়) = $amount', 'Actual deposit (income) = $amount');
  String actualDepositIncomeOnlyMatched(String amount) => _t(
        'বাস্তব জমা (আয়) = $amount — ধার্যকৃত নিসাবের সাথে মিলেছে',
        'Actual deposit (income) = $amount — matches the target নিসাব',
      );
  String actualDepositIncomeOnlyMismatch(String amount, String target) => _t(
        'বাস্তব জমা (আয়) = $amount — ধার্যকৃত নিসাব $target',
        'Actual deposit (income) = $amount — target নিসাব $target',
      );
  String get criteriaByThanaTitle => _t('খাত অনুযায়ী থানার আয় (সবগুলো ঐচ্ছিক)', "থানা's income by criteria (all optional)");
  String get noThanaCriteriaMessage => _t('এই থানার জন্য কোনো খাত নেই।', 'No criteria for this থানা.');

  // ---- widgets/confirm_dialog.dart ----
  String get dialogProtisthanNameLabel => _t('থানার নাম', 'থানা name');
  String get dialogWardNameLabel => _t('ওয়ার্ডের নাম', 'Ward name');
  String get dialogNisabLabel => _t('ধার্যকৃত নিসাব (৳)', 'Target নিসাব (৳)');
  String get dialogNisabHelperShort => _t('ঐচ্ছিক — খালি রাখলে ০ ধরা হবে।', 'Optional — treated as 0 if left blank.');
  String get dialogNisabHelperLong => _t(
        'ঐচ্ছিক — খালি রাখলে ০ ধরা হবে। প্রতি মাসের আয় ও ব্যয়ের '
            'সাথে মিলিয়ে দেখা হবে (আয় − ব্যয় = বাস্তব জমা)।',
        'Optional — treated as 0 if left blank. Compared against each '
            "month's income and expense (income − expense = actual "
            'deposit).',
      );

  // ---- App shell / auth gate ----
  String get authGateLoading => _t('লোড হচ্ছে...', 'Loading...');

  // ---- Login / sign up (auth/login_screen.dart) ----
  String get loginSignUpTitle => _t('নতুন অ্যাকাউন্ট তৈরি করুন', 'Create a new account');
  String get loginSignInTitle => _t('লগইন করুন', 'Sign in');
  String get loginEmail => _t('ইমেইল', 'Email');
  String get loginPassword => _t('পাসওয়ার্ড', 'Password');
  String get loginConfirmPassword => _t('পাসওয়ার্ড নিশ্চিত করুন', 'Confirm password');
  String get loginForgotPassword => _t('পাসওয়ার্ড ভুলে গেছেন?', 'Forgot password?');
  String get loginSignUpButton => _t('নিবন্ধন করুন', 'Sign up');
  String get loginSignInButton => _t('লগইন', 'Sign in');
  String get loginHaveAccount => _t('আগে থেকেই অ্যাকাউন্ট আছে? লগইন করুন', 'Already have an account? Sign in');
  String get loginNewHere => _t('নতুন এখানে? অ্যাকাউন্ট তৈরি করুন', 'New here? Create an account');
  String get loginOr => _t('অথবা', 'or');
  String get loginWithGoogle => _t('Google দিয়ে চালিয়ে যান', 'Continue with Google');
  String get loginEmailRequired => _t('ইমেইল আবশ্যক', 'Email is required');
  String get loginEmailInvalid => _t('সঠিক ইমেইল দিন', 'Enter a valid email');
  String get loginPasswordRequired => _t('পাসওয়ার্ড আবশ্যক', 'Password is required');
  String get loginPasswordTooShort => _t('কমপক্ষে ৮ অক্ষর দিন', 'Enter at least 8 characters');
  String get loginPasswordNeedsDigit => _t('অন্তত একটি সংখ্যা দিন', 'Include at least one digit');
  String get loginPasswordMismatch => _t('পাসওয়ার্ড মিলছে না', 'Passwords do not match');
  String get loginEnterEmailFirst => _t('আগে ইমেইল ঠিকানা লিখুন', 'Enter your email address first');
  String loginResetLinkSent(String email) =>
      _t('$email-এ পাসওয়ার্ড রিসেট লিংক পাঠানো হয়েছে', 'Password reset link sent to $email');
  String get loginErrorInvalidEmail => _t('ইমেইল ঠিকানাটি সঠিক নয়।', 'That email address is invalid.');
  String get loginErrorUserDisabled => _t('এই অ্যাকাউন্টটি নিষ্ক্রিয় করা হয়েছে।', 'This account has been disabled.');
  String get loginErrorUserNotFound =>
      _t('এই ইমেইল/পাসওয়ার্ডে কোনো অ্যাকাউন্ট পাওয়া যায়নি।', 'No account found with this email/password.');
  String get loginErrorWrongPassword => _t('পাসওয়ার্ড সঠিক নয়।', 'Incorrect password.');
  String get loginErrorEmailInUse =>
      _t('এই ইমেইল দিয়ে আগে থেকেই একটি অ্যাকাউন্ট আছে।', 'An account already exists with this email.');
  String get loginErrorWeakPassword =>
      _t('পাসওয়ার্ড খুবই দুর্বল — কমপক্ষে ৬ অক্ষর দিন।', 'Password is too weak — use at least 6 characters.');
  String get loginErrorNetwork => _t('ইন্টারনেট সংযোগ পরীক্ষা করুন।', 'Check your internet connection.');
  String get loginErrorTooManyRequests =>
      _t('অনেকবার চেষ্টা করা হয়েছে — একটু পর আবার চেষ্টা করুন।', 'Too many attempts — try again shortly.');
  String get loginErrorGeneric => _t('একটি সমস্যা হয়েছে, আবার চেষ্টা করুন।', 'Something went wrong — try again.');
  String loginGoogleSignInFailed(String error) =>
      _t('Google সাইন-ইন ব্যর্থ হয়েছে: $error', 'Google sign-in failed: $error');

  // ---- Account screen (screens/account_screen.dart) ----
  String get accountTitle => _t('আমার অ্যাকাউন্ট', 'My account');
  String get accountChangePassword => _t('পাসওয়ার্ড পরিবর্তন', 'Change password');
  String get accountHowItWorks => _t('কীভাবে কাজ করে', 'How it works');
  String get accountSop => _t('বিস্তারিত নিয়মকানুন (SOP)', 'Detailed guidelines (SOP)');
  String get accountDeleteAccount => _t('অ্যাকাউন্ট মুছে ফেলুন', 'Delete account');
  String get accountDeleteSubtitle =>
      _t('আপনার প্রোফাইল ও লগইন স্থায়ীভাবে মুছে যাবে', 'Your profile and login will be permanently deleted');
  String get accountLogout => _t('লগআউট', 'Log out');
  String get accountLanguage => _t('ভাষা', 'Language');
  String get accountLanguageBangla => _t('বাংলা', 'Bangla');
  String get accountLanguageEnglish => _t('English', 'English');

  String get accountChangePasswordDialogTitle => _t('পাসওয়ার্ড পরিবর্তন', 'Change password');
  String get accountCurrentPassword => _t('বর্তমান পাসওয়ার্ড', 'Current password');
  String get accountNewPassword => _t('নতুন পাসওয়ার্ড', 'New password');
  String get accountConfirmNewPassword => _t('নতুন পাসওয়ার্ড নিশ্চিত করুন', 'Confirm new password');
  String get accountChangeButton => _t('পরিবর্তন করুন', 'Change');
  String get accountPasswordChanged => _t('পাসওয়ার্ড পরিবর্তন করা হয়েছে', 'Password changed');

  String get accountLogoutTitle => _t('লগআউট করবেন?', 'Log out?');
  String get accountLogoutMessage => _t('আপনাকে আবার লগইন করতে হবে।', "You'll need to sign in again.");

  String get accountCannotDeleteTitle => _t('অ্যাকাউন্ট মুছে ফেলা যাবে না', 'Cannot delete account');
  String accountCannotDeleteMessage(String list) => _t(
        'আপনি নিচের থানাগুলোর নির্মাতা — এগুলো আগে মুছে ফেলুন বা অন্য থানায় '
            'সরিয়ে নিন, তারপর অ্যাকাউন্ট মুছুন:\n\n$list',
        "You're the creator of the থানা below — delete them or transfer "
            'ownership first, then delete your account:\n\n$list',
      );

  String get accountConfirmPasswordTitle => _t('পাসওয়ার্ড নিশ্চিত করুন', 'Confirm password');
  String get accountConfirmButton => _t('নিশ্চিত করুন', 'Confirm');

  String get accountDeleteConfirmTitle => _t('অ্যাকাউন্ট মুছে ফেলবেন?', 'Delete your account?');
  String get accountDeleteConfirmMessage => _t(
        'আপনার প্রোফাইল, লগইন এবং সকল থানার সদস্যপদ স্থায়ীভাবে মুছে যাবে। '
            'এই কাজটি ফিরিয়ে নেওয়া যাবে না।',
        'Your profile, login, and membership in every থানা will be permanently '
            'deleted. This cannot be undone.',
      );

  String get accountErrorWeakNewPassword => _t(
        'নতুন পাসওয়ার্ড খুবই দুর্বল — কমপক্ষে ৮ অক্ষর, একটি সংখ্যা সহ দিন।',
        'New password is too weak — use at least 8 characters including a digit.',
      );
  String get accountErrorRequiresRecentLogin =>
      _t('নিরাপত্তার জন্য আবার সাইন-ইন করে চেষ্টা করুন।', 'For security, sign in again and retry.');
  String get accountErrorGeneric => _t('একটি সমস্যা হয়েছে।', 'Something went wrong.');

  // ---- Help / SOP static content (screens/help_screen.dart) ----
  String get howItWorksTitle => _t('কীভাবে কাজ করে', 'How it works');
  String get sopTitle => _t('বিস্তারিত নিয়মকানুন (SOP)', 'Detailed guidelines (SOP)');

  List<(String, String)> get howItWorksSections => [
        (
          _t('গঠন', 'Structure'),
          _t(
            'থানা → ওয়ার্ড → খাত → মাসিক এন্ট্রি। প্রতিটি থানার নিজস্ব '
                'ওয়ার্ড ও খাত তালিকা থাকে, আর প্রতি ওয়ার্ডে প্রতি মাসে প্রতিটি '
                'খাতের জন্য একটি করে টাকার অংক এন্ট্রি করা হয়।',
            'থানা (organisation) → Ward → Criteria → monthly entry. Each থানা '
                'has its own list of wards and criteria, and every ward gets '
                'one amount entered per criteria, per month.',
          ),
        ),
        (
          _t('বিশেষ খাত', 'Special criteria'),
          _t(
            'প্রতিটি ওয়ার্ডে চারটি বিশেষ খাত স্বয়ংক্রিয়ভাবে থাকে — '
                'ধার্যকৃত নিসাব (ওয়ার্ড তৈরির সময় ফিক্সড), আয়, ব্যয় (মাসিক '
                'এন্ট্রি), এবং বাস্তব জমা (সবসময় আয় − ব্যয়, স্বয়ংক্রিয়ভাবে '
                'হিসাব হয়)।',
            'Every ward automatically has four special criteria — ধার্যকৃত '
                'নিসাব/target (fixed when the ward is created), income, '
                'expense (monthly entries), and actual deposit (always '
                'income − expense, calculated automatically).',
          ),
        ),
        (
          _t('থানার আয়', "থানা's own income"),
          _t(
            'থানার নিজস্ব সরাসরি কালেকশন — একটি হিডেন "থানা" ওয়ার্ডের '
                'মাধ্যমে ট্র্যাক করা হয়, রিপোর্টে আলাদা রো হিসেবে দেখা যায়।',
            "The থানা's own direct collection — tracked through a hidden "
                '"থানা" ward, shown as its own row in reports.',
          ),
        ),
        (
          _t('রোল সিস্টেম', 'Role system'),
          _t(
            '৪টি রোল — সদস্য (শুধু দেখতে পারবে), কালেক্টর (এন্ট্রি দিতে '
                'পারবে), অ্যাডমিন (ওয়ার্ড/খাত ম্যানেজ ও ইউজার যোগ করতে পারবে), '
                'নির্মাতা (থানা মুছে ফেলা সহ সব কিছু করতে পারবে)। "সদস্য '
                'ব্যবস্থাপনা" থেকে রোল দেওয়া/পরিবর্তন করা যায়।',
            '4 roles — member (view only), collector (can enter data), '
                'admin (can manage wards/criteria and add users), creator '
                '(can do everything, including deleting the থানা). Roles '
                'are assigned/changed from "Member management".',
          ),
        ),
        (
          _t('রিপোর্ট', 'Reports'),
          _t(
            'ম্যাট্রিক্স রিপোর্ট (ওয়ার্ড × খাত টেবিল, PDF/Excel এক্সপোর্ট), '
                'মাসিক কালেকশন সারাংশ, এবং একাধিক মাসের ট্রেন্ড গ্রাফ — সবই '
                'থানার রিপোর্ট ট্যাব থেকে পাওয়া যায়।',
            'Matrix report (ward × criteria table, PDF/Excel export), '
                'monthly collection summary, and a multi-month trend graph '
                "— all from the থানা's Report tab.",
          ),
        ),
        (
          _t('ক্লাউড সিঙ্ক', 'Cloud sync'),
          _t(
            'সব ডেটা Firestore-এ সংরক্ষিত হয় — একাধিক ডিভাইস বা '
                'ব্যবহারকারীর মধ্যে স্বয়ংক্রিয়ভাবে সিঙ্ক হয়। ইন্টারনেট না '
                'থাকলেও অ্যাপ ব্যবহার করা যায়, সংযোগ ফিরলে এন্ট্রি নিজে থেকেই '
                'ক্লাউডে পাঠানো হয়।',
            'All data is stored in Firestore — synced automatically across '
                'devices and users. The app still works offline; entries are '
                'sent to the cloud automatically once the connection returns.',
          ),
        ),
      ];

  List<(String, String)> get sopSections => [
        (
          _t('১. থানা তৈরি ও সদস্য যোগ', '1. Create a থানা and add members'),
          _t(
            'হোম স্ক্রিনের + বোতাম দিয়ে থানা তৈরি করুন — আপনি স্বয়ংক্রিয়ভাবে '
                'এর নির্মাতা হবেন। "সদস্য ব্যবস্থাপনা" থেকে অন্যদের ইমেইল দিয়ে যোগ '
                'করুন ও উপযুক্ত রোল দিন — যাকে যোগ করবেন তাকে আগে একবার অ্যাপে '
                'সাইন-ইন করতে হবে।',
            "Create a থানা with the home screen's + button — you become its "
                'creator automatically. Add others by email from "Member '
                'management" and give them the right role — anyone you add '
                'must have signed in to the app at least once already.',
          ),
        ),
        (
          _t('২. ওয়ার্ড ও খাত সেটআপ', '2. Set up wards and criteria'),
          _t(
            'অ্যাডমিন/নির্মাতা "ওয়ার্ড সমূহ" ট্যাব থেকে ওয়ার্ড যোগ করুন, '
                'প্রতিটির ধার্যকৃত নিসাব নির্ধারণ করুন। "খাত" থেকে অতিরিক্ত খাত '
                'যোগ করুন — বিশেষ চারটি খাত স্বয়ংক্রিয়ভাবে থাকে, মোছা যায় না।',
            'Admin/creator: add wards from the "Wards" tab, and set each '
                'one\'s target amount. Add extra criteria from "Criteria" — '
                'the four special ones already exist automatically and '
                "can't be deleted.",
          ),
        ),
        (
          _t('৩. মাসিক এন্ট্রি', '3. Monthly entries'),
          _t(
            'কালেক্টর/অ্যাডমিন/নির্মাতা প্রতি মাসে প্রতিটি ওয়ার্ডে গিয়ে আয়/ব্যয় '
                'ও অন্যান্য খাতের অংক এন্ট্রি করবেন। একই মাসে আবার এন্ট্রি দিলে আগেরটা '
                'প্রতিস্থাপিত হয়ে যায়। খালি রাখলে সেই এন্ট্রি মুছে যায়।',
            'Collector/admin/creator: enter income/expense and other '
                'criteria amounts for each ward every month. Re-entering the '
                'same month overwrites the previous value; leaving it blank '
                'deletes that entry.',
          ),
        ),
        (
          _t('৪. থানার আয় ও রেমিট্যান্স', "4. থানা's income and remittance"),
          _t(
            '"থানার আয়" থেকে থানার নিজস্ব সংগ্রহ এন্ট্রি করুন। "থানার বাস্তব '
                'জমা খরচ" থেকে মাসিক ব্যয় লিখে থানার প্রকৃত নিসাব হিসাব করুন।',
            'Enter the থানা\'s own direct collection from "থানার আয়". Enter '
                'monthly expense from "থানার বাস্তব জমা খরচ" to calculate the '
                "থানা's actual remaining নিসাব.",
          ),
        ),
        (
          _t('৫. রিপোর্ট পর্যালোচনা', '5. Review reports'),
          _t(
            'প্রতি মাস শেষে ম্যাট্রিক্স রিপোর্ট দেখে সব ওয়ার্ডের এন্ট্রি ঠিক আছে '
                'কিনা যাচাই করুন, প্রয়োজনে PDF/Excel এক্সপোর্ট করে সংরক্ষণ করুন।',
            "At month end, check the matrix report to verify every ward's "
                'entries are correct, and export to PDF/Excel to keep a '
                'record if needed.',
          ),
        ),
        (
          _t('৬. ব্যাকআপ', '6. Backup'),
          _t(
            'নিয়মিত "ডেটা ব্যবস্থাপনা" থেকে JSON ব্যাকআপ এক্সপোর্ট করে নিরাপদ '
                'জায়গায় রাখুন। মনে রাখবেন, ক্লাউড সিঙ্ক থাকলেও local ব্যাকআপ একটি '
                'অতিরিক্ত নিরাপত্তা স্তর — ফাইলটি সংবেদনশীল আর্থিক তথ্য ধারণ করে, তাই '
                'শুধু বিশ্বস্ত জায়গায় শেয়ার/সংরক্ষণ করুন।',
            'Export a JSON backup regularly from "Data management" and keep '
                'it somewhere safe. Even with cloud sync, a local backup is '
                'an extra layer of safety — the file holds sensitive '
                'financial data, so only share/store it somewhere trusted.',
          ),
        ),
        (
          _t('৭. নিরাপত্তা', '7. Security'),
          _t(
            'শক্তিশালী পাসওয়ার্ড ব্যবহার করুন, কাউকে আপনার লগইন তথ্য শেয়ার করবেন '
                'না, প্রয়োজনের বেশি কাউকে অ্যাডমিন/নির্মাতা রোল দেবেন না, এবং কোনো '
                'সদস্য থানা ছেড়ে গেলে তাকে সদস্য ব্যবস্থাপনা থেকে সরিয়ে দিন।',
            'Use a strong password, never share your login with anyone, '
                "don't give out admin/creator roles more than necessary, "
                'and remove a member from "Member management" once they '
                'leave the থানা.',
          ),
        ),
      ];
}
