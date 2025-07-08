import 'package:flutter/material.dart';
import 'package:question_bank/screens/bulk_upload_screen.dart';

import 'package:question_bank/service/local_db.dart';
import 'package:question_bank/widget/medta_datawidegt.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  int _selectedIndex = 0;
  List<DatabaseInfo> _databases = [];
  DatabaseInfo? _selectedDatabase;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final databases = await _localDb.getAllDatabases();
      setState(() {
        _databases = databases;
        if (_databases.isNotEmpty && _selectedDatabase == null) {
          _selectedDatabase = _databases.first;
        }
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }
  }

  Widget _getSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return DashboardHome(
          databases: _databases,
          selectedDatabase: _selectedDatabase,
          onDatabaseSelected: (database) {
            setState(() {
              _selectedDatabase = database;
            });
          },
          onRefresh: _loadDashboardData,
        );
      case 1:
        return const EnhancedBulkUploadScreen();
      case 2:
        return MetadataManager(onMetadataUpdated: () {
          // Refresh if needed
        });
      default:
        return DashboardHome(
          databases: _databases,
          selectedDatabase: _selectedDatabase,
          onDatabaseSelected: (database) {
            setState(() {
              _selectedDatabase = database;
            });
          },
          onRefresh: _loadDashboardData,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.school,
                        size: 48,
                        color: Colors.blue,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Question Bank',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Navigation Items
                Expanded(
                  child: ListView(
                    children: [
                      _buildNavItem(
                        icon: Icons.dashboard,
                        title: 'Dashboard',
                        index: 0,
                        badge: _databases.length.toString(),
                      ),
                      _buildNavItem(
                        icon: Icons.cloud_upload,
                        title: 'Bulk Upload',
                        index: 1,
                        badge: _databases.fold<int>(
                                  0,
                                  (sum, db) => sum + db.uploadQueueCount,
                                ) >
                                0
                            ? _databases
                                .fold<int>(
                                  0,
                                  (sum, db) => sum + db.uploadQueueCount,
                                )
                                .toString()
                            : null,
                      ),
                      _buildNavItem(
                        icon: Icons.settings,
                        title: 'Metadata Manager',
                        index: 2,
                        badge: null,
                      ),
                    ],
                  ),
                ),

                // Stats Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildStatCard(
                        'Total Databases',
                        _databases.length.toString(),
                        Icons.storage,
                        Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      _buildStatCard(
                        'Total Questions',
                        _databases
                            .fold<int>(
                              0,
                              (sum, db) => sum + db.questionCount,
                            )
                            .toString(),
                        Icons.quiz,
                        Colors.green,
                      ),
                      const SizedBox(height: 8),
                      _buildStatCard(
                        'Queue Items',
                        _databases
                            .fold<int>(
                              0,
                              (sum, db) => sum + db.uploadQueueCount,
                            )
                            .toString(),
                        Icons.queue,
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: _getSelectedPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required int index,
    String? badge,
  }) {
    final isSelected = _selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.blue : Colors.grey.shade600,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        selected: isSelected,
        selectedTileColor: Colors.blue.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 1) {
            // Refresh data when going to bulk upload
            _loadDashboardData();
          }
        },
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.8),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardHome extends StatefulWidget {
  final List<DatabaseInfo> databases;
  final DatabaseInfo? selectedDatabase;
  final Function(DatabaseInfo) onDatabaseSelected;
  final VoidCallback onRefresh;

  const DashboardHome({
    Key? key,
    required this.databases,
    this.selectedDatabase,
    required this.onDatabaseSelected,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  final LocalDatabaseService _localDb = LocalDatabaseService();

  @override
  Widget build(BuildContext context) {
    final totalQuestions = widget.databases.fold<int>(
      0,
      (sum, db) => sum + db.questionCount,
    );
    final totalQueueItems = widget.databases.fold<int>(
      0,
      (sum, db) => sum + db.uploadQueueCount,
    );
    final totalUploads = widget.databases.fold<int>(
      0,
      (sum, db) => sum + db.totalUploads,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Overview'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            const Text(
              'Welcome to Question Bank Admin',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your question databases efficiently',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),

            // Overall Stats Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatsCard(
                    'Total Databases',
                    widget.databases.length.toString(),
                    Icons.storage,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatsCard(
                    'Total Questions',
                    totalQuestions.toString(),
                    Icons.quiz,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatsCard(
                    'Queue Items',
                    totalQueueItems.toString(),
                    Icons.queue,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatsCard(
                    'Total Uploads',
                    totalUploads.toString(),
                    Icons.cloud_done,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Databases Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Question Databases',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to bulk upload to create new database
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Database'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Databases List
            Expanded(
              child: widget.databases.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.storage_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No databases found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create a new database to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: widget.databases.length,
                      itemBuilder: (context, index) {
                        final database = widget.databases[index];
                        final isSelected =
                            widget.selectedDatabase?.databaseName ==
                                database.databaseName;

                        return Card(
                          elevation: isSelected ? 8 : 2,
                          color: isSelected ? Colors.blue.shade50 : null,
                          child: InkWell(
                            onTap: () => widget.onDatabaseSelected(database),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.storage,
                                        color: isSelected
                                            ? Colors.blue
                                            : Colors.grey,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          database.displayName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isSelected ? Colors.blue : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Stats
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _buildDatabaseStat(
                                          'Questions',
                                          database.questionCount.toString(),
                                          Icons.quiz,
                                          Colors.green,
                                        ),
                                        const SizedBox(height: 8),
                                        _buildDatabaseStat(
                                          'Queue',
                                          database.uploadQueueCount.toString(),
                                          Icons.queue,
                                          Colors.orange,
                                        ),
                                        const SizedBox(height: 8),
                                        _buildDatabaseStat(
                                          'Uploads',
                                          database.totalUploads.toString(),
                                          Icons.cloud_done,
                                          Colors.purple,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Footer
                                  const Divider(),
                                  Text(
                                    'Last accessed: ${_formatDate(database.lastAccessed)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseStat(
      String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
