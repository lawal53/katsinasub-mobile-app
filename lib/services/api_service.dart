import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Every screen goes through this one class to talk to the website's
/// backend. Change [baseUrl] to your real domain before building.
///
/// This mirrors MOBILE-API-DOCS.md exactly — if you add a new
/// endpoint on the PHP side (e.g. buy-airtime.php), add one matching
/// method here.
class ApiService {
  static const String baseUrl = 'https://katsinasub.com/api/v1/mobile';

  final _storage = const FlutterSecureStorage();

  Future<String?> get _token => _storage.read(key: 'auth_token');

  Future<Map<String, String>> _authHeaders() async {
    final token = await _token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // For multipart/form-data requests (file uploads) — http.MultipartRequest
  // sets its own Content-Type (with boundary) automatically, so we must NOT
  // send 'application/json' here or the server can't parse the upload.
  Future<Map<String, String>> _authHeaderOnly() async {
    final token = await _token;
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String username,
    required String phone,
    required String email,
    required String password,
    required String confirmPassword,
    String? referralCode,
    String? deviceId,
    bool acceptTerms = false,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/register.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'device_id': deviceId ?? '',
        'accept_terms': acceptTerms,
        'full_name': fullName,
        'username': username,
        'phone': phone,
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
        'referral_code': referralCode ?? '',
        'device_name': 'Flutter App',
      }),
    );
    final data = jsonDecode(res.body);
    if (data['success'] == true) {
      await _storage.write(key: 'auth_token', value: data['token']);
    }
    return data;
  }

  Future<Map<String, dynamic>> login({
    required String loginId,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'login_id': loginId,
        'password': password,
        'device_name': 'Flutter App',
      }),
    );
    final data = jsonDecode(res.body);
    if (data['success'] == true) {
      await _storage.write(key: 'auth_token', value: data['token']);
    }
    return data;
  }

  Future<void> logout({String? fcmToken}) async {
    final headers = await _authHeaders();
    await http.post(Uri.parse('$baseUrl/logout.php'), headers: headers, body: jsonEncode({'fcm_token': fcmToken ?? ''}));
    await _storage.delete(key: 'auth_token');
  }

  Future<bool> isLoggedIn() async => (await _token) != null;

  Future<Map<String, dynamic>> me() async {
    final res = await http.get(Uri.parse('$baseUrl/me.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  /// Used only by the app-lock screen to check a typed PIN, without
  /// placing any order. Same PIN as the website's transaction PIN.
  Future<Map<String, dynamic>> verifyPin(String transactionPin) async {
    final res = await http.post(
      Uri.parse('$baseUrl/verify-pin.php'),
      headers: await _authHeaders(),
      body: jsonEncode({'transaction_pin': transactionPin}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> receipt(String reference) async {
    final res = await http.get(
      Uri.parse('$baseUrl/receipt.php?ref=${Uri.encodeQueryComponent(reference)}'),
      headers: await _authHeaders(),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> walletSummary({int page = 1, String category = 'all', String q = ''}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/wallet-summary.php?page=$page&category=$category&q=${Uri.encodeQueryComponent(q)}'),
      headers: await _authHeaders(),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> dataPlans() async {
    final res = await http.get(Uri.parse('$baseUrl/data-plans.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> networks() async {
    final res = await http.get(Uri.parse('$baseUrl/networks.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> buyData({
    required int planId,
    required String phone,
    required String transactionPin,
    bool confirmedMismatch = false,
  }) => _guard(() => _rawBuyData(planId: planId, phone: phone, transactionPin: transactionPin, confirmedMismatch: confirmedMismatch));

  Future<Map<String, dynamic>> _rawBuyData({
    required int planId,
    required String phone,
    required String transactionPin,
    bool confirmedMismatch = false,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/buy-data.php'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'plan_id': planId,
        'phone': phone,
        'transaction_pin': transactionPin,
        'confirmed_mismatch': confirmedMismatch,
      }),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> buyAirtime({
    required String network,
    required String phone,
    required double amount,
    required String transactionPin,
    bool confirmedMismatch = false,
  }) => _guard(() => _rawBuyAirtime(network: network, phone: phone, amount: amount, transactionPin: transactionPin, confirmedMismatch: confirmedMismatch));

  Future<Map<String, dynamic>> _rawBuyAirtime({
    required String network,
    required String phone,
    required double amount,
    required String transactionPin,
    bool confirmedMismatch = false,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/buy-airtime.php'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'network': network,
        'phone': phone,
        'amount': amount,
        'transaction_pin': transactionPin,
        'confirmed_mismatch': confirmedMismatch,
      }),
    );
    return jsonDecode(res.body);
  }

  // ---- Cable TV (two-step: verify, then pay) ----

  Future<Map<String, dynamic>> cablePlans() async {
    final res = await http.get(Uri.parse('$baseUrl/cable-plans.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> verifyCable({required int planId, required String smartcard}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/verify-cable.php'),
      headers: await _authHeaders(),
      body: jsonEncode({'plan_id': planId, 'smartcard': smartcard}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> buyCable({
    required int planId,
    required String smartcard,
    required String phone,
    required String transactionPin,
  }) => _guard(() => _rawBuyCable(planId: planId, smartcard: smartcard, phone: phone, transactionPin: transactionPin));

  Future<Map<String, dynamic>> _rawBuyCable({
    required int planId,
    required String smartcard,
    required String phone,
    required String transactionPin,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/buy-cable.php'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'plan_id': planId,
        'smartcard': smartcard,
        'phone': phone,
        'transaction_pin': transactionPin,
      }),
    );
    return jsonDecode(res.body);
  }

  // ---- Electricity (two-step: verify, then pay) ----

  Future<Map<String, dynamic>> electricityDiscos() async {
    final res = await http.get(Uri.parse('$baseUrl/electricity-discos.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> verifyElectricity({
    required String disco,
    required String meterType,
    required String meterNumber,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/verify-electricity.php'),
      headers: await _authHeaders(),
      body: jsonEncode({'disco': disco, 'meter_type': meterType, 'meter_number': meterNumber}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> buyElectricity({
    required String disco,
    required String meterType,
    required String meterNumber,
    required String phone,
    required double amount,
    required String transactionPin,
  }) => _guard(() => _rawBuyElectricity(disco: disco, meterType: meterType, meterNumber: meterNumber, phone: phone, amount: amount, transactionPin: transactionPin));

  Future<Map<String, dynamic>> _rawBuyElectricity({
    required String disco,
    required String meterType,
    required String meterNumber,
    required String phone,
    required double amount,
    required String transactionPin,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/buy-electricity.php'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'disco': disco,
        'meter_type': meterType,
        'meter_number': meterNumber,
        'phone': phone,
        'amount': amount,
        'transaction_pin': transactionPin,
      }),
    );
    return jsonDecode(res.body);
  }

  // ---- Exam Pins ----
  Future<Map<String, dynamic>> examPlans() async {
    final res = await http.get(Uri.parse('$baseUrl/exam-plans.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> buyExamPin({required String exam, required int quantity, required String phone, required String transactionPin}) => _guard(() => _rawBuyExamPin(exam: exam, quantity: quantity, phone: phone, transactionPin: transactionPin));

  Future<Map<String, dynamic>> _rawBuyExamPin({required String exam, required int quantity, required String phone, required String transactionPin}) async {
    final res = await http.post(Uri.parse('$baseUrl/buy-exam-pin.php'), headers: await _authHeaders(),
        body: jsonEncode({'exam': exam, 'quantity': quantity, 'phone': phone, 'transaction_pin': transactionPin}));
    return jsonDecode(res.body);
  }

  // ---- Transfer To KATSINASUB User ----
  Future<Map<String, dynamic>> transfer({required String identifier, required double amount, required String transactionPin}) async {
    final res = await http.post(Uri.parse('$baseUrl/transfer.php'), headers: await _authHeaders(),
        body: jsonEncode({'identifier': identifier, 'amount': amount, 'transaction_pin': transactionPin}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> transferHistory() async {
    final res = await http.get(Uri.parse('$baseUrl/transfer-history.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> lookupTransferRecipient(String query) async {
    final res = await http.get(Uri.parse('$baseUrl/lookup-transfer-recipient.php?q=${Uri.encodeComponent(query)}'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> transferLimitRequests() async {
    final res = await http.get(Uri.parse('$baseUrl/transfer-limit-request.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> requestTransferLimit({required double requestedLimit, String reason = ''}) async {
    final res = await http.post(Uri.parse('$baseUrl/transfer-limit-request.php'), headers: await _authHeaders(),
        body: jsonEncode({'requested_limit': requestedLimit, 'reason': reason}));
    return jsonDecode(res.body);
  }

  // ---- Bulk SMS ----
  Future<Map<String, dynamic>> bulkSmsInfo() async {
    final res = await http.get(Uri.parse('$baseUrl/buy-bulk-sms.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> buyBulkSms({String? senderId, required String message, required String recipients, required String transactionPin}) => _guard(() => _rawBuyBulkSms(senderId: senderId, message: message, recipients: recipients, transactionPin: transactionPin));

  Future<Map<String, dynamic>> _rawBuyBulkSms({String? senderId, required String message, required String recipients, required String transactionPin}) async {
    final res = await http.post(Uri.parse('$baseUrl/buy-bulk-sms.php'), headers: await _authHeaders(),
        body: jsonEncode({'sender_id': senderId ?? '', 'message': message, 'recipients': recipients, 'transaction_pin': transactionPin}));
    return jsonDecode(res.body);
  }

  // ---- NIN / BVN Verification ----
  Future<Map<String, dynamic>> verifyNin({required String method, required String slipType, required String nin, required String transactionPin}) async {
    final res = await http.post(Uri.parse('$baseUrl/verify-nin.php'), headers: await _authHeaders(),
        body: jsonEncode({'method': method, 'slip_type': slipType, 'nin': nin, 'transaction_pin': transactionPin}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> verifyBvn({required String bvn, required String transactionPin}) async {
    final res = await http.post(Uri.parse('$baseUrl/verify-bvn.php'), headers: await _authHeaders(),
        body: jsonEncode({'bvn': bvn, 'transaction_pin': transactionPin}));
    return jsonDecode(res.body);
  }

  // ---- Recharge / Data Card Printing ----
  Future<Map<String, dynamic>> cardPlans({required String cardType}) async {
    final res = await http.get(Uri.parse('$baseUrl/card-plans.php?type=$cardType'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> buyCard({required String cardType, required int planId, required int quantity, required String transactionPin}) => _guard(() => _rawBuyCard(cardType: cardType, planId: planId, quantity: quantity, transactionPin: transactionPin));

  Future<Map<String, dynamic>> _rawBuyCard({required String cardType, required int planId, required int quantity, required String transactionPin}) async {
    final res = await http.post(Uri.parse('$baseUrl/buy-card.php'), headers: await _authHeaders(),
        body: jsonEncode({'card_type': cardType, 'plan_id': planId, 'quantity': quantity, 'transaction_pin': transactionPin}));
    return jsonDecode(res.body);
  }

  // ---- Airtime to Cash ----
  Future<Map<String, dynamic>> airtimeToCash() async {
    final res = await http.get(Uri.parse('$baseUrl/airtime-to-cash.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> submitAirtimeToCash({required String network, required double amountSent, required String senderPhone}) async {
    final res = await http.post(Uri.parse('$baseUrl/airtime-to-cash.php'), headers: await _authHeaders(),
        body: jsonEncode({'network': network, 'amount_sent': amountSent, 'sender_phone': senderPhone}));
    return jsonDecode(res.body);
  }

  // ---- Bonus Transfer ----
  Future<Map<String, dynamic>> bonusTransfer({required double amount}) async {
    final res = await http.post(Uri.parse('$baseUrl/bonus-transfer.php'), headers: await _authHeaders(), body: jsonEncode({'amount': amount}));
    return jsonDecode(res.body);
  }

  // ---- Account Settings ----
  Future<Map<String, dynamic>> changePassword({required String currentPassword, required String newPassword, required String confirmPassword}) async {
    final res = await http.post(Uri.parse('$baseUrl/account-settings.php'), headers: await _authHeaders(),
        body: jsonEncode({'form': 'password', 'current_password': currentPassword, 'new_password': newPassword, 'confirm_password': confirmPassword}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> changePin({required String newPin, required String confirmPin}) async {
    final res = await http.post(Uri.parse('$baseUrl/account-settings.php'), headers: await _authHeaders(),
        body: jsonEncode({'form': 'pin', 'new_pin': newPin, 'confirm_pin': confirmPin}));
    return jsonDecode(res.body);
  }

  // ---- Delete account (admin approves or rejects) ----
  Future<Map<String, dynamic>> deleteAccountStatus() async {
    final res = await http.get(Uri.parse('$baseUrl/delete-account.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> requestAccountDeletion({required String reason}) async {
    final res = await http.post(Uri.parse('$baseUrl/delete-account.php'), headers: await _authHeaders(), body: jsonEncode({'reason': reason}));
    return jsonDecode(res.body);
  }

  // ---- Referral ----
  Future<Map<String, dynamic>> referral() async {
    final res = await http.get(Uri.parse('$baseUrl/referral.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  // ---- Notifications ----
  Future<Map<String, dynamic>> notifications() async {
    final res = await http.get(Uri.parse('$baseUrl/notifications.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  // ---- Fund Wallet ----
  Future<Map<String, dynamic>> fundWalletInfo() async {
    final res = await http.get(Uri.parse('$baseUrl/fund-wallet.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  // kycType ('bvn' | 'nin') and kycNumber are only sent after the server
  // has answered kyc_required — i.e. the provider asked for the customer's ID.
  Future<Map<String, dynamic>> createVirtualAccount({String? kycType, String? kycNumber}) async {
    final res = await http.post(Uri.parse('$baseUrl/fund-wallet.php'), headers: await _authHeaders(),
        body: jsonEncode({
          'action': 'create_virtual_account',
          if (kycNumber != null) 'kyc_type': kycType,
          if (kycNumber != null) 'kyc_number': kycNumber,
        }));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> createVirtualAccountBillstack({String? kycType, String? kycNumber}) async {
    final res = await http.post(Uri.parse('$baseUrl/fund-wallet.php'), headers: await _authHeaders(),
        body: jsonEncode({
          'action': 'create_virtual_account_billstack',
          if (kycNumber != null) 'kyc_type': kycType,
          if (kycNumber != null) 'kyc_number': kycNumber,
        }));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> fundWalletInit({required String method, required double amount}) async {
    final res = await http.post(Uri.parse('$baseUrl/fund-wallet-init.php'), headers: await _authHeaders(),
        body: jsonEncode({'method': method, 'amount': amount}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> verifyTransaction({required String reference}) async {
    final res = await http.get(Uri.parse('$baseUrl/verify-transaction.php?reference=$reference'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  // ---- Forgot / Reset Password (no auth token yet) ----
  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    final res = await http.post(Uri.parse('$baseUrl/forgot-password.php'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> resetPassword({required String email, required String code, required String password, required String confirmPassword}) async {
    final res = await http.post(Uri.parse('$baseUrl/reset-password.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code, 'password': password, 'confirm_password': confirmPassword}));
    return jsonDecode(res.body);
  }

  // ---- Live Chat ----
  Future<Map<String, dynamic>> fetchChat() async {
    final res = await http.get(Uri.parse('$baseUrl/chat.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> sendChatMessage(String message, {File? attachment}) async {
    if (attachment == null) {
      final res = await http.post(Uri.parse('$baseUrl/chat.php'), headers: await _authHeaders(), body: jsonEncode({'message': message}));
      return jsonDecode(res.body);
    }
    // A photo/screenshot/PDF was picked — send as multipart/form-data,
    // exactly like the website's chat-api.php expects.
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/chat.php'));
    request.headers.addAll(await _authHeaderOnly());
    request.fields['message'] = message;
    request.files.add(await http.MultipartFile.fromPath('attachment', attachment.path));
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    return jsonDecode(body);
  }

  // ---- NIN/BVN Verification History ----
  Future<Map<String, dynamic>> identityHistory() async {
    final res = await http.get(Uri.parse('$baseUrl/identity-history.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  // ---- Email / Phone Verification ----
  Future<Map<String, dynamic>> sendEmailVerification() async {
    final res = await http.post(Uri.parse('$baseUrl/verify-email.php'), headers: await _authHeaders(), body: jsonEncode({'action': 'send'}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> confirmEmailVerification(String code) async {
    final res = await http.post(Uri.parse('$baseUrl/verify-email.php'), headers: await _authHeaders(), body: jsonEncode({'action': 'verify', 'code': code}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> sendPhoneVerification() async {
    final res = await http.post(Uri.parse('$baseUrl/verify-phone.php'), headers: await _authHeaders(), body: jsonEncode({'action': 'send'}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> confirmPhoneVerification(String code) async {
    final res = await http.post(Uri.parse('$baseUrl/verify-phone.php'), headers: await _authHeaders(), body: jsonEncode({'action': 'verify', 'code': code}));
    return jsonDecode(res.body);
  }

  // ---- Push Notifications ----
  Future<Map<String, dynamic>> registerDevice({required String fcmToken, required String platform}) async {
    final res = await http.post(Uri.parse('$baseUrl/register-device.php'), headers: await _authHeaders(),
        body: jsonEncode({'fcm_token': fcmToken, 'platform': platform}));
    return jsonDecode(res.body);
  }

  // ---- Support ----
  Future<Map<String, dynamic>> supportInfo() async {
    final res = await http.get(Uri.parse('$baseUrl/support-info.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  // ---------------------------------------------------------------------
  // Purchases: if the connection drops while the server is still working,
  // the customer must NOT be told a vague "could not reach the server".
  // We ask the server for the newest order of the last minutes and show
  // exactly the response that Transaction History / the receipt shows.
  // ---------------------------------------------------------------------
  Future<Map<String, dynamic>> _guard(Future<Map<String, dynamic>> Function() call) async {
    final started = DateTime.now();
    try {
      return await call().timeout(const Duration(seconds: 120));
    } catch (_) {
      return _recoverAfterCutOff(DateTime.now().difference(started).inSeconds + 15);
    }
  }

  Future<Map<String, dynamic>> _recoverAfterCutOff(int seconds) async {
    for (var i = 0; i < 3; i++) {
      try {
        await Future.delayed(Duration(seconds: i == 0 ? 2 : 4));
        final res = await http
            .get(Uri.parse('$baseUrl/latest-transaction.php?seconds=$seconds'), headers: await _authHeaders())
            .timeout(const Duration(seconds: 20));
        final j = jsonDecode(res.body);
        if (j is Map && j['found'] == true) {
          final st = '${j['status']}';
          final msg = '${j['message'] ?? ''}';
          if (st == 'successful') return {'success': true, 'status': 'successful', 'message': msg, 'reference': j['reference']};
          if (st == 'failed') return {'success': false, 'status': 'failed', 'message': msg, 'reference': j['reference']};
          if (i == 2) return {'success': true, 'status': 'processing', 'message': msg.isNotEmpty ? msg : 'Your order is being processed.', 'reference': j['reference']};
          continue;
        }
      } catch (_) {}
    }
    return {
      'success': false,
      'message': 'We could not confirm the result because of a weak connection. Please open Transaction History to check it before trying again. If nothing appears there, you were not charged.',
    };
  }

  // ---- Rewards & programmes ----
  Future<Map<String, dynamic>> rewards() async {
    final res = await http.get(Uri.parse('$baseUrl/rewards.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> claimReward(int id) async {
    final res = await http.post(Uri.parse('$baseUrl/rewards.php'), headers: await _authHeaders(), body: jsonEncode({'action': 'claim', 'reward_id': id}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> redeemReward({required int id, required String phone, String network = '', required String pin, bool confirmMismatch = false}) async {
    final res = await http.post(Uri.parse('$baseUrl/rewards.php'),
        headers: await _authHeaders(),
        body: jsonEncode({'action': 'redeem', 'reward_id': id, 'phone': phone, 'network': network, 'pin': pin, 'confirm_mismatch': confirmMismatch}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> programs() async {
    final res = await http.get(Uri.parse('$baseUrl/programs.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> programDetail(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/programs.php?id=$id'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> joinProgram(int id) async {
    final res = await http.post(Uri.parse('$baseUrl/programs.php'), headers: await _authHeaders(), body: jsonEncode({'action': 'join', 'program_id': id}));
    return jsonDecode(res.body);
  }

  // ---- Change email (old email first, then the new one) ----
  Future<Map<String, dynamic>> emailChangeState() async {
    final res = await http.get(Uri.parse('$baseUrl/email-change.php'), headers: await _authHeaders());
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> emailChange(String action, {String? code, String? email}) async {
    final res = await http.post(Uri.parse('$baseUrl/email-change.php'),
        headers: await _authHeaders(), body: jsonEncode({'action': action, if (code != null) 'code': code, if (email != null) 'email': email}));
    return jsonDecode(res.body);
  }

  // ---- Saved beneficiaries ----
  Future<List<dynamic>> beneficiaries(String type) async {
    final res = await http.get(Uri.parse('$baseUrl/beneficiaries.php?type=$type'), headers: await _authHeaders());
    final j = jsonDecode(res.body);
    return (j is Map && j['success'] == true) ? (j['beneficiaries'] as List<dynamic>? ?? []) : [];
  }

  Future<Map<String, dynamic>> addBeneficiary({required String type, required String value, String name = ''}) async {
    final res = await http.post(Uri.parse('$baseUrl/beneficiaries.php'),
        headers: await _authHeaders(), body: jsonEncode({'action': 'add', 'type': type, 'value': value, 'name': name}));
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> deleteBeneficiary(int id) async {
    final res = await http.post(Uri.parse('$baseUrl/beneficiaries.php'),
        headers: await _authHeaders(), body: jsonEncode({'action': 'delete', 'id': id}));
    return jsonDecode(res.body);
  }
}
