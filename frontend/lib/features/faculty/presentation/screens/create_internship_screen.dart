import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';

class CreateInternshipScreen extends ConsumerStatefulWidget {
  const CreateInternshipScreen({super.key});

  @override
  ConsumerState<CreateInternshipScreen> createState() =>
      _CreateInternshipScreenState();
}

class _CreateInternshipScreenState
    extends ConsumerState<CreateInternshipScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _stipendMinCtrl = TextEditingController();
  final _stipendMaxCtrl = TextEditingController();
  final _openingsCtrl = TextEditingController(text: '1');
  final _weeksCtrl = TextEditingController();
  final _cgpaCtrl = TextEditingController();
  final _deadlineCtrl = TextEditingController();
  String _mode = 'hybrid';
  bool _loading = false;
  XFile? _posterImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _companyCtrl,
      _descCtrl,
      _locationCtrl,
      _skillsCtrl,
      _stipendMinCtrl,
      _stipendMaxCtrl,
      _openingsCtrl,
      _weeksCtrl,
      _cgpaCtrl,
      _deadlineCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _posterImage = image);
    }
  }

  Future<String?> _uploadImage() async {
    if (_posterImage == null) return null;
    final client = ref.read(dioClientProvider);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(_posterImage!.path,
            filename: _posterImage!.name),
      });
      final res = await client.dio.post('/upload/image', data: formData);
      return res.data['url'] as String?;
    } catch (e) {
      debugPrint('Image upload failed: $e');
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      String? posterUrl = await _uploadImage();
      final client = ref.read(dioClientProvider);
      await client.dio.post(ApiConstants.facultyInternships, data: {
        'title': _titleCtrl.text.trim(),
        'company_name': _companyCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'mode': _mode,
        'poster_url': posterUrl,
        'location': _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        'required_skills': _skillsCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'stipend_min': _stipendMinCtrl.text.isEmpty
            ? null
            : int.tryParse(_stipendMinCtrl.text),
        'stipend_max': _stipendMaxCtrl.text.isEmpty
            ? null
            : int.tryParse(_stipendMaxCtrl.text),
        'openings': int.tryParse(_openingsCtrl.text) ?? 1,
        'duration_weeks':
            _weeksCtrl.text.isEmpty ? null : int.tryParse(_weeksCtrl.text),
        'min_cgpa':
            _cgpaCtrl.text.isEmpty ? null : double.tryParse(_cgpaCtrl.text),
        'application_deadline':
            _deadlineCtrl.text.isEmpty ? null : _deadlineCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Internship created! Tap Publish when ready.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post New Internship'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section('Basic Information'),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 160,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _posterImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(_posterImage!.path,
                                  fit: BoxFit.cover)
                              : Image.file(File(_posterImage!.path),
                                  fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Upload Poster/Banner (Optional)',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
              _field(_titleCtrl, 'Job Title *', required: true),
              _field(_companyCtrl, 'Company Name *', required: true),
              _field(_descCtrl, 'Description *', required: true, maxLines: 4),
              _section('Location & Mode'),
              _field(_locationCtrl, 'Location (city, state)'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'remote', label: Text('Remote')),
                  ButtonSegment(value: 'hybrid', label: Text('Hybrid')),
                  ButtonSegment(value: 'onsite', label: Text('On-site')),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? AppColors.primary
                          : AppColors.bgCard),
                ),
              ),
              _section('Skills & Requirements'),
              _field(_skillsCtrl, 'Required Skills (comma-separated)',
                  hint: 'e.g. Flutter, Python, SQL'),
              _field(_cgpaCtrl, 'Min CGPA', keyboardType: TextInputType.number),
              _section('Compensation & Details'),
              Row(
                children: [
                  Expanded(
                      child: _field(_stipendMinCtrl, 'Min Stipend (₹)',
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _field(_stipendMaxCtrl, 'Max Stipend (₹)',
                          keyboardType: TextInputType.number)),
                ],
              ),
              Row(
                children: [
                  Expanded(
                      child: _field(_openingsCtrl, 'Openings',
                          keyboardType: TextInputType.number, required: true)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _field(_weeksCtrl, 'Duration (weeks)',
                          keyboardType: TextInputType.number)),
                ],
              ),
              _field(_deadlineCtrl, 'Application Deadline', hint: 'YYYY-MM-DD'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Internship',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
        child: Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    int maxLines = 1,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            filled: true,
            fillColor: AppColors.bgCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
          ),
          validator: required
              ? (v) =>
                  v == null || v.trim().isEmpty ? '$label is required' : null
              : null,
        ),
      );
}
