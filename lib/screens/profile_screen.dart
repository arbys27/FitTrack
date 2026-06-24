import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../themes/app_theme.dart';
import '../widgets/fitness_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.surfaceColor, AppTheme.backgroundColor],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Consumer2<AuthProvider, ProfileProvider>(
            builder: (context, authProvider, profileProvider, _) {
              final user = authProvider.currentUser;
              final profileUser = profileProvider.userProfile ?? user;
              
              final height = profileUser?.height ?? 175;
              final weight = profileUser?.weight ?? 70;
              final bmi = weight / ((height / 100) * (height / 100));
              final bmiCategory = profileUser?.getBMICategory() ?? 'Normal';
              final fitnessGoal = profileUser?.fitnessGoal ?? 'Stay Active';

              return ListView(
                children: [
                  Text('Profile', style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 20),
                  
                  // User info card
                  SectionCard(
                    child: Row(
                      children: [
                        _buildAvatar(profileUser?.photoURL ?? ''),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
  (profileUser?.name != null && profileUser!.name.trim().isNotEmpty)
      ? profileUser.name
      : (user?.name ?? 'FitTrack User'),
  style: Theme.of(context).textTheme.titleLarge,
),
                              const SizedBox(height: 4),
                              Text(
                                profileUser?.email ?? 'user@example.com',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  fitnessGoal,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Metrics row
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          title: 'Weight',
                          value: '${weight.toStringAsFixed(1)} kg',
                          icon: Icons.monitor_weight_rounded,
                          iconColor: AppTheme.accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricCard(
                          title: 'BMI',
                          value: bmi.toStringAsFixed(1),
                          icon: Icons.health_and_safety_rounded,
                          iconColor: AppTheme.primaryColor,
                          subtitle: bmiCategory,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Detailed info card
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile Information',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Age', '${profileUser?.age ?? 25} years'),
                        const SizedBox(height: 12),
                        _buildInfoRow('Gender', profileUser?.gender ?? 'Not specified'),
                        const SizedBox(height: 12),
                        _buildInfoRow('Height', '${height.toStringAsFixed(1)} cm'),
                        const SizedBox(height: 12),
                        _buildInfoRow('Weight', '${weight.toStringAsFixed(1)} kg'),
                        const SizedBox(height: 12),
                        _buildInfoRow('BMI Category', bmiCategory),
                        const SizedBox(height: 12),
                        _buildInfoRow('Fitness Goal', fitnessGoal),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Edit profile button (optional for future implementation)
                 
                  
                  // Logout button
                  PrimaryActionButton(
                    label: 'Logout',
                    icon: Icons.logout_rounded,
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        print('🚪 Logout confirmed. Clearing all data...');
                        // Clear all provider states before logout
                        if (context.mounted) {
                          await AuthProvider.clearAllProvidersOnLogout(context);
                        }
                        await authProvider.logout();
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
    );

  /// Build info row widget
  Widget _buildInfoRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );  

      Widget _buildAvatar(String photoURL) {
  if (photoURL.isNotEmpty) {
    return CircleAvatar(
      radius: 34,
      backgroundColor: AppTheme.primaryColor,
      backgroundImage: NetworkImage(photoURL),
      onBackgroundImageError: (_, __) {},
      child: null,
    );
  }
  return const CircleAvatar(
    radius: 34,
    backgroundColor: AppTheme.primaryColor,
    child: Icon(Icons.person, size: 34, color: Colors.black),
  );
}
}
