import 'package:dio/dio.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'token_store.dart';

/// One method per backend endpoint. Screens never touch Dio directly.
class Api {
  final ApiClient c;
  final TokenStore store;
  Api(this.c, this.store);

  Map<String, dynamic> _m(dynamic d) => d as Map<String, dynamic>;
  List<Map<String, dynamic>> _l(dynamic d) => (d as List).map((e) => e as Map<String, dynamic>).toList();

  // ---- auth ----
  Future<void> register(String email, String password, String firstName, String businessName) => c.call(
      () => c.dio.post('/api/auth/register',
          data: {'email': email, 'password': password, 'first_name': firstName, 'business_name': businessName},
          options: _noAuth),
      (_) {});

  Future<void> login(String email, String password) async {
    final tokens = await c.call(
        () => c.dio.post('/api/auth/login', data: {'email': email, 'password': password}, options: _noAuth),
        (d) => _m(d));
    await store.save(access: tokens['access'] as String, refresh: tokens['refresh'] as String);
  }

  Future<Me> me() => c.call(() => c.dio.get('/api/auth/me'), (d) => Me.fromJson(_m(d)));

  // ---- business ----
  Future<Business> updateBusiness(Map<String, dynamic> body) =>
      c.call(() => c.dio.put('/api/business', data: body), (d) => Business.fromJson(_m(d)));

  // ---- products ----
  Future<List<Product>> products({String q = ''}) => c.call(
      () => c.dio.get('/api/products', queryParameters: {if (q.isNotEmpty) 'q': q, 'limit': 200}),
      (d) => _l(d).map(Product.fromJson).toList());

  Future<Product> createProduct(Map<String, dynamic> body) =>
      c.call(() => c.dio.post('/api/products', data: body), (d) => Product.fromJson(_m(d)));

  Future<void> updateProduct(int id, Map<String, dynamic> body) =>
      c.call(() => c.dio.patch('/api/products/$id', data: body), (_) {});

  Future<void> deleteProduct(int id) => c.call(() => c.dio.delete('/api/products/$id'), (_) {});

  Future<void> addVariant(int productId, Map<String, dynamic> body) =>
      c.call(() => c.dio.post('/api/products/$productId/variants', data: body), (_) {});

  Future<void> updateVariant(int id, Map<String, dynamic> body) =>
      c.call(() => c.dio.patch('/api/products/variants/$id', data: body), (_) {});

  Future<void> deleteVariant(int id) => c.call(() => c.dio.delete('/api/products/variants/$id'), (_) {});

  // ---- faqs ----
  Future<List<Faq>> faqs() => c.call(() => c.dio.get('/api/faqs'), (d) => _l(d).map(Faq.fromJson).toList());
  Future<void> createFaq(String q, String a) =>
      c.call(() => c.dio.post('/api/faqs', data: {'question': q, 'answer': a}), (_) {});
  Future<void> updateFaq(int id, String q, String a) =>
      c.call(() => c.dio.patch('/api/faqs/$id', data: {'question': q, 'answer': a}), (_) {});
  Future<void> deleteFaq(int id) => c.call(() => c.dio.delete('/api/faqs/$id'), (_) {});

  // ---- leads ----
  Future<List<Lead>> leads({String? status, String q = ''}) => c.call(
      () => c.dio.get('/api/leads', queryParameters: {
            if (status != null) 'status': status,
            if (q.isNotEmpty) 'q': q,
            'limit': 200,
          }),
      (d) => _l(d).map(Lead.fromJson).toList());

  Future<List<Lead>> followups() =>
      c.call(() => c.dio.get('/api/leads/followups'), (d) => _l(d).map(Lead.fromJson).toList());

  Future<Lead> createLead(String name, String phone) => c.call(
      () => c.dio.post('/api/leads', data: {'customer_name': name, 'phone': phone}), (d) => Lead.fromJson(_m(d)));

  Future<Lead> lead(int id) => c.call(() => c.dio.get('/api/leads/$id'), (d) => Lead.fromJson(_m(d)));

  /// Pass `clearFollowup: true` to remove the reminder.
  Future<void> updateLead(int id,
      {String? status, String? name, String? phone, String? notes, DateTime? followupAt, bool clearFollowup = false}) {
    final body = <String, dynamic>{
      if (status != null) 'status': status,
      if (name != null) 'customer_name': name,
      if (phone != null) 'phone': phone,
      if (notes != null) 'notes': notes,
      if (followupAt != null) 'next_followup_at': followupAt.toUtc().toIso8601String(),
      if (clearFollowup) 'next_followup_at': null,
    };
    return c.call(() => c.dio.patch('/api/leads/$id', data: body), (_) {});
  }

  Future<void> deleteLead(int id) => c.call(() => c.dio.delete('/api/leads/$id'), (_) {});

  Future<void> addMessage(int leadId, String direction, String text) => c.call(
      () => c.dio.post('/api/leads/$leadId/messages', data: {'direction': direction, 'text': text}), (_) {});

  // ---- AI ----
  Future<Reply> reply(String message,
          {int? leadId, String? language, String? tone, String instruction = '', bool saveMessage = true}) =>
      c.call(
          () => c.dio.post('/api/ai/reply', options: _aiOptions, data: {
                'message': message,
                if (leadId != null) 'lead_id': leadId,
                if (language != null) 'language': language,
                if (tone != null) 'tone': tone,
                'instruction': instruction,
                'save_message': saveMessage,
              }),
          (d) => Reply.fromJson(_m(d)));

  Future<Reply> refine(int draftId, String instruction) => c.call(
      () => c.dio.post('/api/ai/reply/$draftId/refine', options: _aiOptions, data: {'instruction': instruction}),
      (d) => Reply.fromJson(_m(d)));

  Future<Reply> followupDraft(int leadId) => c.call(
      () => c.dio.post('/api/ai/followup', options: _aiOptions, data: {'lead_id': leadId}), (d) => Reply.fromJson(_m(d)));

  Future<Extract> extractOrder(String message, {int? leadId}) => c.call(
      () => c.dio.post('/api/ai/extract-order', options: _aiOptions, data: {'message': message, if (leadId != null) 'lead_id': leadId}),
      (d) => Extract.fromJson(_m(d)));

  /// Tell the server what the seller actually copied (quality metric).
  Future<void> draftFeedback(int draftId, String finalText) => c.call(
      () => c.dio.patch('/api/ai/drafts/$draftId', data: {'final_text': finalText}), (_) {});

  // ---- orders ----
  Future<List<Order>> orders({String? status}) => c.call(
      () => c.dio.get('/api/orders', queryParameters: {if (status != null) 'status': status, 'limit': 200}),
      (d) => _l(d).map(Order.fromJson).toList());

  Future<Order> order(int id) => c.call(() => c.dio.get('/api/orders/$id'), (d) => Order.fromJson(_m(d)));

  Future<Order> createOrder(Map<String, dynamic> body) =>
      c.call(() => c.dio.post('/api/orders', data: body), (d) => Order.fromJson(_m(d)));

  Future<Order> setOrderStatus(int id, String status) => c.call(
      () => c.dio.patch('/api/orders/$id/status', data: {'status': status}), (d) => Order.fromJson(_m(d)));

  Future<void> deleteOrder(int id) => c.call(() => c.dio.delete('/api/orders/$id'), (_) {});

  Future<String> orderSummary(int id) =>
      c.call(() => c.dio.get('/api/orders/$id/summary'), (d) => _m(d)['text'] as String);

  // ---- dashboard / usage ----
  Future<Dashboard> dashboard() =>
      c.call(() => c.dio.get('/api/dashboard/summary'), (d) => Dashboard.fromJson(_m(d)));

  Future<UsageStats> usage() => c.call(() => c.dio.get('/api/usage'), (d) => UsageStats.fromJson(_m(d)));
}

// ignore: prefer_const_declarations
final _noAuth = Options(extra: {'noAuth': true});

final _aiOptions = Options(receiveTimeout: const Duration(seconds: 60));
