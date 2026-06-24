import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../themes/app_theme.dart';

/// Screen for setting up fitness profile on first login
class FitnessProfileSetupScreen extends StatefulWidget {
  const FitnessProfileSetupScreen({super.key});

  @override
  State<FitnessProfileSetupScreen> createState() => _FitnessProfileSetupScreenState();
}

class _FitnessProfileSetupScreenState extends State<FitnessProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form field controllers
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  // Form field values
  String _selectedGender = 'Male';
  String _selectedFitnessGoal = 'Stay Active';
  bool _isLoading = false;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _fitnessGoals = ['Lose Weight', 'Gain Muscle', 'Stay Active'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  /// Validate and save profile
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final profileProvider = context.read<ProfileProvider>();
      final userId = authProvider.currentUser?.id;
      
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: User ID not found. Please try logging in again.'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      print('💾 [FitnessProfileSetupScreen] Saving fitness profile...');
      print('   UID: $userId');
      print('   Name: ${_nameController.text.trim()}');

      final success = await profileProvider.saveFitnessProfile(
        userId: userId,
        name: _nameController.text.trim(),
        gender: _selectedGender,
        age: int.parse(_ageController.text),
        height: double.parse(_heightController.text),
        weight: double.parse(_weightController.text),
        fitnessGoal: _selectedFitnessGoal,
      );

      if (!mounted) return;

      if (success) {
        print('✅ [FitnessProfileSetupScreen] Profile saved successfully!');
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile setup completed!'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );

        // Wait a moment for Firestore to persist the data
        await Future.delayed(const Duration(milliseconds: 500));

        // Force reload the profile to ensure isProfileCompleted is updated
        print('🔄 [FitnessProfileSetupScreen] Reloading profile...');
        await profileProvider.forceRefreshProfile(userId);
        
        if (!mounted) return;

        print('🎯 [FitnessProfileSetupScreen] Signaling profile completion to AuthGate...');
        // Signal to AuthGate that profile completion status has changed
        // This will trigger AuthGate to re-resolve the route and navigate to Dashboard
        final authProvider = context.read<AuthProvider>();
        authProvider.signalProfileCompletionStatusChanged();
      } else {
        print('❌ [FitnessProfileSetupScreen] Failed to save profile: ${profileProvider.errorMessage}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(profileProvider.errorMessage ?? 'Failed to save profile'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ [FitnessProfileSetupScreen] Exception saving profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverAppBar(
              floating: true,
              backgroundColor: AppTheme.backgroundColor,
              elevation: 0,
              centerTitle: true,
              title: Text(
                'Complete Your Profile',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            // Form content
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Description
                  Text(
                    'Help us personalize your fitness experience by completing your profile.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                  ),
                  const SizedBox(height: 30),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Full Name
                        _buildFormField(
                          label: 'Full Name',
                          controller: _nameController,
                          hint: 'Enter your full name',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Gender Selection
                        Text(
                          'Gender',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildGenderSelection(),
                        const SizedBox(height: 20),

                        // Age
                        _buildFormField(
                          label: 'Age',
                          controller: _ageController,
                          hint: 'Enter your age',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your age';
                            }
                            final age = int.tryParse(value);
                            if (age == null || age < 10 || age > 120) {
                              return 'Please enter a valid age (10-120)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Height (cm)
                        _buildFormField(
                          label: 'Height (cm)',
                          controller: _heightController,
                          hint: 'Enter your height in cm',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your height';
                            }
                            final height = double.tryParse(value);
                            if (height == null || height < 100 || height > 250) {
                              return 'Please enter a valid height (100-250 cm)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Weight (kg)
                        _buildFormField(
                          label: 'Weight (kg)',
                          controller: _weightController,
                          hint: 'Enter your weight in kg',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your weight';
                            }
                            final weight = double.tryParse(value);
                            if (weight == null || weight < 30 || weight > 300) {
                              return 'Please enter a valid weight (30-300 kg)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Fitness Goal Dropdown
                        Text(
                          'Fitness Goal',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildFitnessGoalDropdown(),
                        const SizedBox(height: 40),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                    ),
                                  )
                                : Text(
                                    'Continue to Dashboard',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );

  /// Build form field widget
  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    FormFieldValidator<String>? validator,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
              filled: true,
              fillColor: AppTheme.surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.errorColor,
                  width: 2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.errorColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      );

  /// Build gender selection widget
  Widget _buildGenderSelection() => Row(
        children: _genders.map((gender) => Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => setState(() => _selectedGender = gender),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedGender == gender ? AppTheme.primaryColor : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedGender == gender ? AppTheme.primaryColor : AppTheme.borderColor,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      gender,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: _selectedGender == gender ? Colors.black : AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          )).toList(),
      );

  /// Build fitness goal dropdown
  Widget _buildFitnessGoalDropdown() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: DropdownButton<String>(
          value: _selectedFitnessGoal,
          isExpanded: true,
          underline: const SizedBox(),
          style: Theme.of(context).textTheme.bodyMedium,
          items: _fitnessGoals.map((goal) => DropdownMenuItem<String>(
              value: goal,
              child: Text(goal),
            )).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedFitnessGoal = value);
            }
          },
        ),
      );
}
