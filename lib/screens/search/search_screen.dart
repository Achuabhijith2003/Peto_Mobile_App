import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_text_field.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final List<String> _trendingTags = [
    '#GoldenRetriever',
    '#KittenCare',
    '#VetTips',
    '#DogTraining',
    '#PetAdoption',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Peto'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.outline,
          indicatorColor: AppColors.primaryContainer,
          tabs: const [
            Tab(text: 'Posts'),
            Tab(text: 'Communities'),
            Tab(text: 'Users'),
            Tab(text: 'Pets'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomTextField(
              label: '',
              hint: 'Search posts, breeds, users or communities...',
              controller: _searchController,
              prefixIcon: const Icon(Icons.search, color: AppColors.outline),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: AppColors.outline),
                onPressed: () => _searchController.clear(),
              ),
            ),
          ),

          // Trending hashtags
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              height: 32,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _trendingTags.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _trendingTags[index],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSearchList('posts'),
                _buildSearchList('communities'),
                _buildSearchList('users'),
                _buildSearchList('pets'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchList(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 48,
            color: AppColors.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Type above to search $type',
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
