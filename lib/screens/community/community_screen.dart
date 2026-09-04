import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/community_card.dart';
import '../../widgets/auth_prompt_bottom_sheet.dart';
import 'community_detail_screen.dart';
import 'create_community_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  final List<String> _categories = [
    'All',
    'Dogs',
    'Cats',
    'Birds',
    'Fish & Aquatics',
    'Exotic',
    'Health & Care',
    'Training',
    'Adoption',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final commProvider = Provider.of<CommunityProvider>(context, listen: false);
      _searchController.text = commProvider.searchQuery;
      commProvider.fetchCommunities();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        Provider.of<CommunityProvider>(context, listen: false).setSearchQuery(query);
      }
    });
  }

  void _openCreateCommunity(BuildContext context, AuthProvider authProvider) {
    if (!authProvider.isAuthenticated) {
      AuthPromptBottomSheet.show(context, actionTitle: 'Create a Circle');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final commProvider = Provider.of<CommunityProvider>(context);

    final sortTabs = [
      {'id': 'popular', 'label': '🔥 Popular'},
      {'id': 'new', 'label': '✨ Newest'},
      {'id': 'joined', 'label': '🐾 Joined'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pet Circles',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            tooltip: 'Create Circle',
            onPressed: () => _openCreateCommunity(context, authProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateCommunity(context, authProvider),
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('New Circle', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await commProvider.fetchCommunities();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search input
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search circles by name, topic, or breed...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                    prefixIcon: const Icon(Icons.search, color: AppColors.onSurfaceVariant),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppColors.onSurfaceVariant),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Discovery Sort Tabs ("Popular", "Newest", "Joined")
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: sortTabs.map((tab) {
                    final isSelected = commProvider.selectedSort == tab['id'];
                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          if (tab['id'] == 'joined' && !authProvider.isAuthenticated) {
                            AuthPromptBottomSheet.show(context, actionTitle: 'View Joined Circles');
                            return;
                          }
                          commProvider.setSort(tab['id']!);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            tab['label']!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // Category scroll
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    return CategoryChip(
                      label: cat,
                      isSelected: commProvider.selectedCategory == cat,
                      onTap: () => commProvider.setCategory(cat),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Title count & info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    commProvider.selectedSort == 'joined'
                        ? 'Circles You Joined'
                        : commProvider.selectedCategory == 'All'
                            ? 'All Circles'
                            : '${commProvider.selectedCategory} Circles',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  if (!commProvider.isLoading)
                    Text(
                      '${commProvider.communities.length} found',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Main Community List
              if (commProvider.isLoading) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ] else if (commProvider.error != null) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 44),
                        const SizedBox(height: 12),
                        Text(
                          commProvider.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => commProvider.fetchCommunities(),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (commProvider.communities.isEmpty) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.groups_outlined,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          commProvider.selectedSort == 'joined'
                              ? "You haven't joined any circles yet"
                              : 'No circles found',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          commProvider.selectedSort == 'joined'
                              ? 'Browse popular circles and tap Join to connect with other pet parents!'
                              : 'Try changing your search terms or category filter.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (commProvider.selectedSort == 'joined')
                          ElevatedButton.icon(
                            onPressed: () => commProvider.setSort('popular'),
                            icon: const Icon(Icons.explore_outlined, size: 18),
                            label: const Text('Explore Circles'),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () => _openCreateCommunity(context, authProvider),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Start This Circle'),
                          ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: commProvider.communities.length,
                  itemBuilder: (context, index) {
                    final comm = commProvider.communities[index];
                    return CommunityCard(
                      community: comm,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CommunityDetailScreen(
                              communityId: comm.id,
                              initialCommunity: comm,
                            ),
                          ),
                        ).then((_) {
                          // Refresh list to capture membership change or post count updates
                          commProvider.fetchCommunities();
                        });
                      },
                      onJoinToggle: () {
                        if (authProvider.isAuthenticated) {
                          commProvider.toggleJoin(comm.id);
                        } else {
                          AuthPromptBottomSheet.show(context, actionTitle: 'Join Community');
                        }
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
