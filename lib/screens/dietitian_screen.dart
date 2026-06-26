import 'package:diet_cure/core/models/app_user.dart';
import 'package:diet_cure/core/providers/auth_provider.dart';
import 'package:diet_cure/core/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:diet_cure/utils/app_styles.dart';
import 'package:provider/provider.dart';

class DietitianScreen extends StatefulWidget {
  const DietitianScreen({super.key});

  @override
  State<DietitianScreen> createState() => _DietitianScreenState();
}

class _DietitianScreenState extends State<DietitianScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All Clients';
  final int _currentPage = 1;
  final int _totalClients = 124;
  final UserService _userService = UserService();
  List<AppUser> _allClients = [];
  bool _isLoading = true;

  @override
  void initState(){
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final clients = await _userService.fetchAllClients();
    setState(() {
      _allClients = clients;
      _isLoading = false;
    });
  }

  List<AppUser> get _filteredClients {
    return _allClients.where((client) {
      final nameMatches = client.displayName.toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final idMatches = client.uid.toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return nameMatches || idMatches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if(_isLoading){
      print('the widget is loading.');
      return const Center(child: Text('Fetching data from the Firestore'));
    }

    print('going into the actual widget');
    return Scaffold(
      backgroundColor: AppTheme.warmSand,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildSearchAndFilters(),
              const SizedBox(height: 24),
              _buildClientsTable(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primary,
      elevation: 4,
      shadowColor: AppTheme.onSurface.withValues(alpha: 0.1),
      title: Row(
        children: [
          Text(
            'DietCure',
            style: GoogleFonts.quicksand(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(width: 48),
          _buildNavTab('Dashboard', false),
          _buildNavTab('Clients', true),
          _buildNavTab('Meal Plans', false),
          _buildNavTab('Analytics', false),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.white),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () {},
        ),
        const SizedBox(width: 16),
        _buildProfileDropdown(),
        const SizedBox(width: 24),
      ],
    );
  }

  Widget _buildNavTab(String title, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.7),
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 3,
              width: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildProfileDropdown() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.surfaceContainerLowest,
          child: Icon(Icons.person, color: AppTheme.darkAzure, size: 20),
        ),
      ),
      onSelected: (value) async{
        switch (value){
          case 'profile':
          break;

          case 'clients_list':
          break;

          case 'diets_list':
          break;

          case 'sign_out':
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            await authProvider.signOut();
            break;
        }
      },
      itemBuilder: (context) => [
        _buildMenuItem('profile', 'Profile', Icons.account_circle_outlined),
        _buildMenuItem('clients_list', 'Clients List', Icons.people_outline),
        _buildMenuItem('diets_list', 'Diets List', Icons.restaurant_menu),
        const PopupMenuDivider(),
        _buildMenuItem('sign_out', 'Sign Out', Icons.logout, isDestructive: true),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, String label, IconData icon, {bool isDestructive = false}) {
    final color = isDestructive ? AppTheme.dustyRose : AppTheme.darkAzure;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.roboto(
              color: color,
              fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Client Management',
          style: GoogleFonts.quicksand(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your professional practice and track patient progress from a single viewpoint.',
          style: GoogleFonts.roboto(
            fontSize: 16,
            color: AppTheme.darkAzure.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        Container(
          width: 500,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.darkAzure.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            style: GoogleFonts.roboto(fontSize: 15, color: AppTheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Filter by client name, ID or diet code...',
              hintStyle: GoogleFonts.roboto(
                color: AppTheme.darkAzure.withValues(alpha: 0.4),
              ),
              prefixIcon: Icon(Icons.search, color: AppTheme.darkAzure.withValues(alpha: 0.6)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Filter Chips Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildFilterChip('All Clients'),
                const SizedBox(width: 8),
                _buildFilterChip('Recent'),
                const SizedBox(width: 8),
                _buildFilterChip('Active'),
              ],
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.filter_list, size: 18),
              label: Text(
                'Advanced Filters',
                style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryDark,
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.darkAzure,
          ),
        ),
      ),
    );
  }

  Widget _buildClientsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onSurface.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell('CLIENT ID', flex: 2),
                _buildHeaderCell('CLIENT NAME', flex: 3),
                _buildHeaderCell('DIET CODE', flex: 3),
                _buildHeaderCell('LAST APPOINTMENT', flex: 3),
                _buildHeaderCell('ACTIONS', flex: 1, alignRight: true),
              ],
            ),
          ),
          
          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredClients.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.darkAzure.withValues(alpha: 0.05),
            ),
            itemBuilder: (context, index) {
              final client = _filteredClients[index];
              return _buildClientRow(client, index % 2 == 0);
            },
          ),
          
          // Pagination Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: AppTheme.onSurface,
                    ),
                    children: [
                      const TextSpan(text: 'Displaying '),
                      TextSpan(
                        text: '${_filteredClients.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                      ),
                      const TextSpan(text: ' of '),
                      TextSpan(
                        text: '$_totalClients',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                      ),
                      const TextSpan(text: ' total clients'),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: AppTheme.darkAzure.withValues(alpha: 0.5)),
                      onPressed: () {},
                      splashRadius: 20,
                    ),
                    Text(
                      '$_currentPage',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: AppTheme.primaryDark),
                      onPressed: () {},
                      splashRadius: 20,
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {required int flex, bool alignRight = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppTheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
 
  Widget _buildClientRow(AppUser client, bool isEven) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: isEven ? Colors.white : AppTheme.warmSand.withValues(alpha: 0.3),
      child: Row(
        children: [
          // Client ID
          Expanded(
            flex: 2,
            child: Text(
              client.uid,
              style: GoogleFonts.robotoMono(
                fontSize: 14,
                color: AppTheme.darkAzure.withValues(alpha: 0.6),
              ),
            ),
          ),
          
          // Client Name
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.surfaceContainerLowest,
                  child: const Icon(
                    Icons.person,
                    size: 16,
                    color: AppTheme.darkAzure,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  client.displayName,
                  style: GoogleFonts.roboto(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          
          // Diet Code Tag
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.darkAzure.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  client.role.name,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
          ),
          
          // Last Appointment
          Expanded(
            flex: 3,
            child: Text(
              client.email ?? 'N/A',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: AppTheme.darkAzure.withValues(alpha: 0.8),
              ),
            ),
          ),
          
          // Actions Menu
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.more_vert, color: AppTheme.primary),
                onPressed: () {},
                splashRadius: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}