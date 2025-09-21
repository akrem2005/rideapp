import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

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
    _searchController.addListener(_filterCodes);
    _fetchDiscountCodes(); // fetch data on load
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _fetchDiscountCodes() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final query = QueryBuilder<ParseObject>(ParseObject('DiscountCode'))
        ..orderByDescending('createdAt');

      final response = await query.query();

      if (!mounted) return;

      if (response.success && response.results != null) {
        discountCodes = response.results!
            .map((e) => DiscountCode.fromParse(e as ParseObject))
            .toList();
        filteredCodes = discountCodes;
      } else {
        _hasError = true;
        discountCodes = [];
        filteredCodes = [];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to fetch discount codes: ${response.error?.message ?? "Unknown error"}',
            ),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _hasError = true;
      discountCodes = [];
      filteredCodes = [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code "$code" copied to clipboard!'),
        backgroundColor: const Color(0xFF34A853),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryTextColor = Color(0xFF21201E);
    const greyBackground = Color(0xFFF5F4F2);
    const yellowAccent = Color(0xFFF5E10E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top back arrow and title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.arrow_back, color: Color(0xFF21201E)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Discount Codes',
                    style: TextStyle(
                      color: Color(0xFF21201E),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search discount codes...',
                  filled: true,
                  fillColor: greyBackground,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Discount codes list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
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
                              color: yellowAccent,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount: filteredCodes.length,
                                itemBuilder: (context, index) {
                                  final discount = filteredCodes[index];
                                  return Card(
                                    color: greyBackground,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),

                                      // Add gift.png in front of each item
                                      leading: Image.asset(
                                        'lib/shared/assets/gift.png', // make sure this path matches your assets folder
                                        width: 32,
                                        height: 32,
                                      ),

                                      title: Text(
                                        discount.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Code: ${discount.code}',
                                          style: TextStyle(
                                              color: primaryTextColor
                                                  .withOpacity(0.7)),
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.copy),
                                        color: yellowAccent,
                                        onPressed: () =>
                                            _copyToClipboard(discount.code),
                                      ),
                                      onTap: () =>
                                          _copyToClipboard(discount.code),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),

            // Bottom copyright
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Text(
                "© All rights reserved",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
