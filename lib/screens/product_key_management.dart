import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:question_bank/model/product_key.dart';
import 'package:question_bank/service/metadata_service.dart';
import 'package:question_bank/service/product_key_service.dart';

class ProductKeyManagementScreen extends StatefulWidget {
  const ProductKeyManagementScreen({Key? key}) : super(key: key);

  @override
  State<ProductKeyManagementScreen> createState() =>
      _ProductKeyManagementScreenState();
}

class _ProductKeyManagementScreenState
    extends State<ProductKeyManagementScreen> {
  final ProductKeyService _keyService = ProductKeyService();
  final MetadataService _metadataService = MetadataService();

  List<ProductKeyModel> _productKeys = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await _metadataService.loadAllMetadata();
      final keys = await _keyService.getAllProductKeys();
      final stats = await _keyService.getProductKeyStats();

      setState(() {
        _productKeys = keys;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load data: $e');
    }
  }

  List<ProductKeyModel> get _filteredKeys {
    return _productKeys.where((key) {
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          key.productKey.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          key.coachingName.toLowerCase().contains(_searchQuery.toLowerCase());

      // Status filter
      final matchesStatus = _statusFilter == 'all' ||
          (_statusFilter == 'active' && key.isActive && !key.isExpired) ||
          (_statusFilter == 'expired' && key.isExpired) ||
          (_statusFilter == 'disabled' && !key.isActive) ||
          (_statusFilter == 'unused' && !key.isUsed);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Key Management'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats Cards
                _buildStatsSection(),

                // Search and Filter Bar
                _buildSearchAndFilterBar(),

                // Product Keys List
                Expanded(
                  child: _buildProductKeysList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateKeyDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Key'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Keys',
              _stats['totalKeys']?.toString() ?? '0',
              Icons.vpn_key,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Active',
              _stats['activeKeys']?.toString() ?? '0',
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Expired',
              _stats['expiredKeys']?.toString() ?? '0',
              Icons.schedule,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Devices',
              _stats['totalDevices']?.toString() ?? '0',
              Icons.devices,
              Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by key or coaching name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Filter',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              value: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'expired', child: Text('Expired')),
                DropdownMenuItem(value: 'disabled', child: Text('Disabled')),
                DropdownMenuItem(value: 'unused', child: Text('Unused')),
              ],
              onChanged: (value) {
                setState(() => _statusFilter = value ?? 'all');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductKeysList() {
    final filteredKeys = _filteredKeys;

    if (filteredKeys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.vpn_key_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No product keys found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new product key to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredKeys.length,
      itemBuilder: (context, index) {
        final key = filteredKeys[index];
        return _buildProductKeyCard(key);
      },
    );
  }

  Widget _buildProductKeyCard(ProductKeyModel key) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.vpn_key,
                            color: _getStatusColor(key),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            key.productKey,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _copyToClipboard(key.productKey),
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: 'Copy Key',
                          ),
                        ],
                      ),
                      Text(
                        key.coachingName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(key).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _getStatusColor(key).withOpacity(0.3)),
                  ),
                  child: Text(
                    key.statusText,
                    style: TextStyle(
                      color: _getStatusColor(key),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Details Grid
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    'Duration',
                    '${key.subscriptionDurationMonths} months',
                    Icons.schedule,
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    'Devices',
                    '${key.currentDeviceCount}/${key.maxDevices}',
                    Icons.devices,
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    'Created',
                    _formatDate(key.createdAt),
                    Icons.calendar_today,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Streams and Languages
            if (key.allowedStreams.isNotEmpty)
              _buildChipSection('Streams', key.allowedStreams, Colors.blue),

            if (key.allowedLanguages.isNotEmpty) const SizedBox(height: 8),

            if (key.allowedLanguages.isNotEmpty)
              _buildChipSection(
                  'Languages', key.allowedLanguages, Colors.green),

            // Expiry Info
            if (key.isUsed && key.expiresAt != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: key.isExpired
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: key.isExpired
                        ? Colors.red.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      key.isExpired ? Icons.error : Icons.access_time,
                      color: key.isExpired ? Colors.red : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      key.isExpired
                          ? 'Expired on ${_formatDate(key.expiresAt!)}'
                          : 'Expires on ${_formatDate(key.expiresAt!)}',
                      style: TextStyle(
                        color: key.isExpired ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Notes
            if (key.notes != null && key.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        key.notes!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showKeyDetailsDialog(key),
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditKeyDialog(key),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleKeyStatus(key),
                    icon: Icon(
                      key.isActive ? Icons.block : Icons.check_circle,
                      size: 16,
                    ),
                    label: Text(key.isActive ? 'Disable' : 'Enable'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: key.isActive ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildChipSection(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: items
              .map((item) => Chip(
                    label: Text(
                      item,
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: color.withOpacity(0.1),
                    side: BorderSide(color: color.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Color _getStatusColor(ProductKeyModel key) {
    if (!key.isActive) return Colors.red;
    if (key.isExpired) return Colors.orange;
    if (!key.isUsed) return Colors.grey;
    return Colors.green;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleKeyStatus(ProductKeyModel key) async {
    try {
      await _keyService.toggleProductKeyStatus(key.keyId!, !key.isActive);
      _loadData();
      _showSuccessSnackBar(
        key.isActive ? 'Product key disabled' : 'Product key enabled',
      );
    } catch (e) {
      _showErrorSnackBar('Failed to update key status: $e');
    }
  }

  void _showCreateKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateProductKeyDialog(
        metadataService: _metadataService,
        onKeyCreated: (key) {
          _loadData();
          _showSuccessSnackBar('Product key created: ${key.productKey}');
        },
      ),
    );
  }

  void _showEditKeyDialog(ProductKeyModel key) {
    showDialog(
      context: context,
      builder: (context) => EditProductKeyDialog(
        productKey: key,
        metadataService: _metadataService,
        onKeyUpdated: (updatedKey) {
          _loadData();
          _showSuccessSnackBar('Product key updated');
        },
      ),
    );
  }

  void _showKeyDetailsDialog(ProductKeyModel key) {
    showDialog(
      context: context,
      builder: (context) => ProductKeyDetailsDialog(
        productKey: key,
        keyService: _keyService,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class CreateProductKeyDialog extends StatefulWidget {
  final MetadataService metadataService;
  final Function(ProductKeyModel) onKeyCreated;

  const CreateProductKeyDialog({
    Key? key,
    required this.metadataService,
    required this.onKeyCreated,
  }) : super(key: key);

  @override
  State<CreateProductKeyDialog> createState() => _CreateProductKeyDialogState();
}

class _CreateProductKeyDialogState extends State<CreateProductKeyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _coachingNameController = TextEditingController();
  final _notesController = TextEditingController();
  final ProductKeyService _keyService = ProductKeyService();

  int _subscriptionMonths = 12;
  int _maxDevices = 1;
  List<String> _selectedStreams = [];
  List<String> _selectedLanguages = [];
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Product Key'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Coaching Name
                TextFormField(
                  controller: _coachingNameController,
                  decoration: const InputDecoration(
                    labelText: 'Coaching Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter coaching name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Subscription Duration
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'Subscription Duration',
                          border: OutlineInputBorder(),
                        ),
                        value: _subscriptionMonths,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 Month')),
                          DropdownMenuItem(value: 3, child: Text('3 Months')),
                          DropdownMenuItem(value: 6, child: Text('6 Months')),
                          DropdownMenuItem(value: 12, child: Text('12 Months')),
                          DropdownMenuItem(value: 24, child: Text('24 Months')),
                        ],
                        onChanged: (value) {
                          setState(() => _subscriptionMonths = value ?? 12);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'Max Devices',
                          border: OutlineInputBorder(),
                        ),
                        value: _maxDevices,
                        items: List.generate(10, (index) => index + 1)
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(
                                      '$value Device${value > 1 ? 's' : ''}'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() => _maxDevices = value ?? 1);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Allowed Streams
                _buildMultiSelectField(
                  'Allowed Streams *',
                  widget.metadataService.streams,
                  _selectedStreams,
                  (selected) => setState(() => _selectedStreams = selected),
                ),

                const SizedBox(height: 16),

                // Allowed Languages
                _buildMultiSelectField(
                  'Allowed Languages *',
                  widget.metadataService.languages,
                  _selectedLanguages,
                  (selected) => setState(() => _selectedLanguages = selected),
                ),

                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createProductKey,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Widget _buildMultiSelectField(
    String label,
    List<String> options,
    List<String> selected,
    Function(List<String>) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = selected.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (isChipSelected) {
                  if (isChipSelected) {
                    onChanged([...selected, option]);
                  } else {
                    onChanged(selected.where((s) => s != option).toList());
                  }
                },
              );
            }).toList(),
          ),
        ),
        if (selected.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please select at least one option',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _createProductKey() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStreams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one stream'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one language'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final productKey = await _keyService.createProductKey(
        coachingName: _coachingNameController.text.trim(),
        subscriptionDurationMonths: _subscriptionMonths,
        maxDevices: _maxDevices,
        allowedStreams: _selectedStreams,
        allowedLanguages: _selectedLanguages,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      Navigator.pop(context);
      widget.onKeyCreated(productKey);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create product key: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }
}

class EditProductKeyDialog extends StatefulWidget {
  final ProductKeyModel productKey;
  final MetadataService metadataService;
  final Function(ProductKeyModel) onKeyUpdated;

  const EditProductKeyDialog({
    Key? key,
    required this.productKey,
    required this.metadataService,
    required this.onKeyUpdated,
  }) : super(key: key);

  @override
  State<EditProductKeyDialog> createState() => _EditProductKeyDialogState();
}

class _EditProductKeyDialogState extends State<EditProductKeyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _coachingNameController = TextEditingController();
  final _notesController = TextEditingController();
  final ProductKeyService _keyService = ProductKeyService();

  late int _maxDevices;
  late List<String> _selectedStreams;
  late List<String> _selectedLanguages;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _coachingNameController.text = widget.productKey.coachingName;
    _notesController.text = widget.productKey.notes ?? '';
    _maxDevices = widget.productKey.maxDevices;
    _selectedStreams = List.from(widget.productKey.allowedStreams);
    _selectedLanguages = List.from(widget.productKey.allowedLanguages);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Product Key: ${widget.productKey.productKey}'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Coaching Name
                TextFormField(
                  controller: _coachingNameController,
                  decoration: const InputDecoration(
                    labelText: 'Coaching Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter coaching name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Max Devices (only allow increase)
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Max Devices',
                    border: OutlineInputBorder(),
                    helperText: 'Can only be increased',
                  ),
                  value: _maxDevices,
                  items: List.generate(10, (index) => index + 1)
                      .where((value) => value >= widget.productKey.maxDevices)
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value Device${value > 1 ? 's' : ''}'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _maxDevices = value ?? _maxDevices);
                  },
                ),

                const SizedBox(height: 16),

                // Allowed Streams
                _buildMultiSelectField(
                  'Allowed Streams *',
                  widget.metadataService.streams,
                  _selectedStreams,
                  (selected) => setState(() => _selectedStreams = selected),
                ),

                const SizedBox(height: 16),

                // Allowed Languages
                _buildMultiSelectField(
                  'Allowed Languages *',
                  widget.metadataService.languages,
                  _selectedLanguages,
                  (selected) => setState(() => _selectedLanguages = selected),
                ),

                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateProductKey,
          child: _isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }

  Widget _buildMultiSelectField(
    String label,
    List<String> options,
    List<String> selected,
    Function(List<String>) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = selected.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (isChipSelected) {
                  if (isChipSelected) {
                    onChanged([...selected, option]);
                  } else {
                    onChanged(selected.where((s) => s != option).toList());
                  }
                },
              );
            }).toList(),
          ),
        ),
        if (selected.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please select at least one option',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _updateProductKey() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStreams.isEmpty || _selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one stream and language'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final updatedKey = widget.productKey.copyWith(
        coachingName: _coachingNameController.text.trim(),
        maxDevices: _maxDevices,
        allowedStreams: _selectedStreams,
        allowedLanguages: _selectedLanguages,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await _keyService.updateProductKey(updatedKey);

      Navigator.pop(context);
      widget.onKeyUpdated(updatedKey);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update product key: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }
}

class ProductKeyDetailsDialog extends StatefulWidget {
  final ProductKeyModel productKey;
  final ProductKeyService keyService;

  const ProductKeyDetailsDialog({
    Key? key,
    required this.productKey,
    required this.keyService,
  }) : super(key: key);

  @override
  State<ProductKeyDetailsDialog> createState() =>
      _ProductKeyDetailsDialogState();
}

class _ProductKeyDetailsDialogState extends State<ProductKeyDetailsDialog> {
  List<DeviceRegistrationModel> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final devices = await widget.keyService
          .getDevicesForKey(widget.productKey.productKey);
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Key Details: ${widget.productKey.productKey}'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Info
              _buildInfoCard('Basic Information', [
                _buildInfoRow('Coaching Name', widget.productKey.coachingName),
                _buildInfoRow('Status', widget.productKey.statusText),
                _buildInfoRow('Duration',
                    '${widget.productKey.subscriptionDurationMonths} months'),
                _buildInfoRow('Max Devices', '${widget.productKey.maxDevices}'),
                _buildInfoRow('Current Devices',
                    '${widget.productKey.currentDeviceCount}'),
                _buildInfoRow(
                    'Created At', _formatDateTime(widget.productKey.createdAt)),
                if (widget.productKey.firstUsedAt != null)
                  _buildInfoRow('First Used',
                      _formatDateTime(widget.productKey.firstUsedAt!)),
                if (widget.productKey.expiresAt != null)
                  _buildInfoRow('Expires At',
                      _formatDateTime(widget.productKey.expiresAt!)),
              ]),

              const SizedBox(height: 16),

              // Allowed Streams
              _buildInfoCard(
                'Allowed Streams',
                widget.productKey.allowedStreams
                    .map((stream) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Chip(
                              label: Text(stream,
                                  style: const TextStyle(fontSize: 12))),
                        ))
                    .toList(),
              ),

              const SizedBox(height: 16),

              // Allowed Languages
              _buildInfoCard(
                'Allowed Languages',
                widget.productKey.allowedLanguages
                    .map((lang) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Chip(
                              label: Text(lang,
                                  style: const TextStyle(fontSize: 12))),
                        ))
                    .toList(),
              ),

              if (widget.productKey.notes != null &&
                  widget.productKey.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildInfoCard('Notes', [
                  Text(widget.productKey.notes!,
                      style: const TextStyle(fontSize: 14)),
                ]),
              ],

              const SizedBox(height: 16),

              // Registered Devices
              _buildDevicesSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Registered Devices',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _loadDevices,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_devices.isEmpty)
              const Text(
                'No devices registered yet',
                style: TextStyle(color: Colors.grey),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        Icons.devices,
                        color: device.isActive ? Colors.green : Colors.grey,
                      ),
                      title: Text(device.deviceName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: ${device.deviceId}'),
                          Text(
                              'Registered: ${_formatDateTime(device.registeredAt)}'),
                          Text(
                              'Last Active: ${_formatDateTime(device.lastActiveAt)}'),
                        ],
                      ),
                      trailing: IconButton(
                        onPressed: () => _removeDevice(device),
                        icon:
                            const Icon(Icons.remove_circle, color: Colors.red),
                        tooltip: 'Remove Device',
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeDevice(DeviceRegistrationModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device'),
        content: Text(
            'Are you sure you want to remove device "${device.deviceName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.keyService.removeDeviceFromKey(
          widget.productKey.keyId!,
          device.deviceId,
        );
        _loadDevices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device removed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove device: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
