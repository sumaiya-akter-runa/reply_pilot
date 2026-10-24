// Plain data classes that mirror the FastAPI responses.

double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
int _i(dynamic v) => v == null ? 0 : (v as num).toInt();
String _s(dynamic v) => v == null ? '' : v.toString();
DateTime? _t(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();
List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    (v as List? ?? []).map((e) => f(e as Map<String, dynamic>)).toList();

String taka(double v) => v == v.roundToDouble() ? '${v.toInt()} Tk' : '${v.toStringAsFixed(2)} Tk';

class Business {
  final int id;
  final String name, phone, address, deliveryPolicy, returnPolicy, paymentMethods, tone, defaultLanguage;
  final double defaultDeliveryCharge;
  Business.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = _s(j['name']),
        phone = _s(j['phone']),
        address = _s(j['address']),
        deliveryPolicy = _s(j['delivery_policy']),
        returnPolicy = _s(j['return_policy']),
        paymentMethods = _s(j['payment_methods']),
        tone = _s(j['tone']),
        defaultLanguage = _s(j['default_language']),
        defaultDeliveryCharge = _d(j['default_delivery_charge']);
}

class Me {
  final int id;
  final String email, firstName, plan;
  final Business business;
  Me.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        email = _s(j['email']),
        firstName = _s(j['first_name']),
        plan = _s(j['plan']),
        business = Business.fromJson(j['business'] as Map<String, dynamic>);
}

class Variant {
  final int id, productId, stockQty, lowStockThreshold;
  final String label;
  final bool isLowStock;
  Variant.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        productId = _i(j['product_id']),
        label = _s(j['label']),
        stockQty = _i(j['stock_qty']),
        lowStockThreshold = _i(j['low_stock_threshold']),
        isLowStock = j['is_low_stock'] == true;
}

class Product {
  final int id, totalStock;
  final String name, description;
  final double price;
  final bool isActive, hasLowStock;
  final List<Variant> variants;
  Product.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = _s(j['name']),
        description = _s(j['description']),
        price = _d(j['price']),
        isActive = j['is_active'] == true,
        totalStock = _i(j['total_stock']),
        hasLowStock = j['has_low_stock'] == true,
        variants = _list(j['variants'], Variant.fromJson);
}

class Faq {
  final int id;
  final String question, answer;
  Faq.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        question = _s(j['question']),
        answer = _s(j['answer']);
}

class Message {
  final int id;
  final String direction, text;
  final DateTime? createdAt;
  Message.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        direction = _s(j['direction']),
        text = _s(j['text']),
        createdAt = _t(j['created_at']);
  bool get fromCustomer => direction == 'customer';
}

class Lead {
  final int id;
  final String customerName, phone, source, status, notes;
  final DateTime? nextFollowupAt, updatedAt;
  final List<Message> messages;
  Lead.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        customerName = _s(j['customer_name']),
        phone = _s(j['phone']),
        source = _s(j['source']),
        status = _s(j['status']),
        notes = _s(j['notes']),
        nextFollowupAt = _t(j['next_followup_at']),
        updatedAt = _t(j['updated_at']),
        messages = _list(j['messages'], Message.fromJson);
  String get title => customerName.isEmpty ? 'Lead #$id' : customerName;
}

class OrderItem {
  final String productName, variantLabel;
  final int quantity;
  final double unitPrice, lineTotal;
  OrderItem.fromJson(Map<String, dynamic> j)
      : productName = _s(j['product_name']),
        variantLabel = _s(j['variant_label']),
        quantity = _i(j['quantity']),
        unitPrice = _d(j['unit_price']),
        lineTotal = _d(j['line_total']);
}

class Order {
  final int id;
  final int? leadId;
  final String customerName, phone, address, status, note;
  final double deliveryCharge, subtotal, total;
  final DateTime? createdAt;
  final List<OrderItem> items;
  Order.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        leadId = j['lead_id'] == null ? null : _i(j['lead_id']),
        customerName = _s(j['customer_name']),
        phone = _s(j['phone']),
        address = _s(j['address']),
        status = _s(j['status']),
        note = _s(j['note']),
        deliveryCharge = _d(j['delivery_charge']),
        subtotal = _d(j['subtotal']),
        total = _d(j['total']),
        createdAt = _t(j['created_at']),
        items = _list(j['items'], OrderItem.fromJson);
}

class Usage {
  final String plan;
  final int used, limit, remaining;
  Usage.fromJson(Map<String, dynamic> j)
      : plan = _s(j['plan']),
        used = _i(j['used']),
        limit = _i(j['limit']),
        remaining = _i(j['remaining']);
}

class UsageStats extends Usage {
  final int draftsTotal, draftsWithFeedback, draftsSentUnedited;
  UsageStats.fromJson(Map<String, dynamic> j)
      : draftsTotal = _i(j['drafts_total']),
        draftsWithFeedback = _i(j['drafts_with_feedback']),
        draftsSentUnedited = _i(j['drafts_sent_unedited']),
        super.fromJson(j);
}

class Reply {
  final int draftId;
  final String reply, intent;
  final bool needsSellerCheck;
  final List<String> missingInfo, warnings;
  final Usage usage;
  Reply.fromJson(Map<String, dynamic> j)
      : draftId = _i(j['draft_id']),
        reply = _s(j['reply']),
        intent = _s(j['intent']),
        needsSellerCheck = j['needs_seller_check'] == true,
        missingInfo = (j['missing_info'] as List? ?? []).map((e) => e.toString()).toList(),
        warnings = (j['warnings'] as List? ?? []).map((e) => e.toString()).toList(),
        usage = Usage.fromJson(j['usage'] as Map<String, dynamic>);
}

class ExtractItem {
  final bool matched;
  final int? productId, variantId;
  final String productName, variantLabel;
  final int quantity;
  final double? unitPrice;
  final bool? inStock;
  ExtractItem.fromJson(Map<String, dynamic> j)
      : matched = j['matched'] == true,
        productId = j['product_id'] == null ? null : _i(j['product_id']),
        variantId = j['variant_id'] == null ? null : _i(j['variant_id']),
        productName = _s(j['product_name']),
        variantLabel = _s(j['variant_label']),
        quantity = _i(j['quantity']),
        unitPrice = j['unit_price'] == null ? null : _d(j['unit_price']),
        inStock = j['in_stock'] as bool?;
}

class Extract {
  final String customerName, phone, address;
  final List<ExtractItem> items;
  final List<String> missingFields;
  Extract.fromJson(Map<String, dynamic> j)
      : customerName = _s(j['customer_name']),
        phone = _s(j['phone']),
        address = _s(j['address']),
        items = _list(j['items'], ExtractItem.fromJson),
        missingFields = (j['missing_fields'] as List? ?? []).map((e) => e.toString()).toList();
}

class Dashboard {
  final int newLeadsToday, followupsDue, ordersToday, pendingOrders, lowStockCount;
  final double revenueToday;
  final Map<String, int> leadsByStatus;
  final Usage usage;
  Dashboard.fromJson(Map<String, dynamic> j)
      : newLeadsToday = _i(j['new_leads_today']),
        followupsDue = _i(j['followups_due']),
        ordersToday = _i(j['orders_today']),
        pendingOrders = _i(j['pending_orders']),
        lowStockCount = _i(j['low_stock_count']),
        revenueToday = _d(j['revenue_today']),
        leadsByStatus = (j['leads_by_status'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), _i(v))),
        usage = Usage.fromJson(j['usage'] as Map<String, dynamic>);
}
