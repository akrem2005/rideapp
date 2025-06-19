import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

// Model for discount code
class DiscountCode {
  final String objectId;
  final String title;
  final double amount;
  final String code;

  DiscountCode({
    required this.objectId,
    required this.title,
    required this.amount,
    required this.code,
  });

  factory DiscountCode.fromParse(ParseObject object) {
    final amountValue = object.get<num>('amount');
    final title = object.get<String>('title');
    final code = object.get<String>('code');

    if (object.objectId == null || title == null || code == null) {
      throw const FormatException('Missing required fields in DiscountCode');
    }
    if (amountValue == null || amountValue < 0 || amountValue > 100) {
      throw const FormatException('Invalid discount amount');
    }
    if (code.isEmpty) {
      throw const FormatException('Discount code cannot be empty');
    }

    return DiscountCode(
      objectId: object.objectId!,
      title: title,
      amount: amountValue.toDouble(),
      code: code,
    );
  }
}

class DiscountPage extends StatefulWidget {
  const DiscountPage({super.key});

  @override
  State<DiscountPage> createState() => _DiscountPageState();
}

class _DiscountPageState extends State<DiscountPage> {
  List<DiscountCode> discountCodes = [];
  List<DiscountCode> filteredCodes = [];
  bool _isLoading = false;
  bool _hasError = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDiscountCodes();
    _searchController.addListener(_filterCodes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDiscountCodes() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final query = QueryBuilder<ParseObject>(ParseObject('DiscountCode'))
        ..orderByDescending('createdAt');
      final response = await query.query();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (response.success && response.results != null) {
          discountCodes = response.results!
              .map((e) => DiscountCode.fromParse(e as ParseObject))
              .toList();
          filteredCodes = discountCodes;
        } else {
          _hasError = true;
          _showSnackBar(
            'Failed to fetch discount codes: ${response.error?.message ?? "Unknown error"}',
            isError: true,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      _showSnackBar('An error occurred: $e', isError: true);
    }
  }

  void _filterCodes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredCodes = discountCodes
          .where((code) =>
              code.title.toLowerCase().contains(query) ||
              code.code.toLowerCase().contains(query))
          .toList();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    _showSnackBar('Code "$code" copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: Color(0xFFFFA500),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFFFFA500),
          primary: Color(0xFFFFA500),
          secondary: Colors.blue[100],
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Discount Codes',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _fetchDiscountCodes,
            ),
          ],
          elevation: 0,
          backgroundColor: Color(0xFFFFA500),
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading discounts...'),
                        ],
                      ),
                    )
                  : _hasError
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red[700],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Failed to load discount codes',
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _fetchDiscountCodes,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : filteredCodes.isEmpty
                          ? const Center(
                              child: Text(
                                'No discount codes found',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchDiscountCodes,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount: filteredCodes.length,
                                itemBuilder: (context, index) {
                                  final discount = filteredCodes[index];
                                  return AnimatedScale(
                                    scale: 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Card(
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.all(16),
                                        title: Text(
                                          discount.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Discount: ${discount.amount.toStringAsFixed(1)}% | Code: ${discount.code}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.copy),
                                          color: Color(0xFFFFA500),
                                          tooltip: 'Copy Code',
                                          onPressed: () =>
                                              _copyToClipboard(discount.code),
                                        ),
                                        onTap: () =>
                                            _copyToClipboard(discount.code),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
