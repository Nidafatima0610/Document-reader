import 'package:all_documents_reader/core/theme/app_theme.dart';
import 'package:all_documents_reader/models/career_models.dart';
import 'package:all_documents_reader/services/career_pdf_service.dart';
import 'package:all_documents_reader/views/career_document_preview_view.dart';
import 'package:flutter/material.dart';

/// Professional Offline CV / Resume Builder
class CareerResumeBuilderView extends StatefulWidget {
  final ResumeData? initialData;

  const CareerResumeBuilderView({super.key, this.initialData});

  @override
  State<CareerResumeBuilderView> createState() =>
      _CareerResumeBuilderViewState();
}

class _CareerResumeBuilderViewState extends State<CareerResumeBuilderView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _titleController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _locationController;
  late TextEditingController _linkedInController;
  late TextEditingController _websiteController;
  late TextEditingController _summaryController;

  final List<WorkExperience> _experiences = [];
  final List<EducationItem> _education = [];
  final List<String> _skills = [];
  final List<ProjectItem> _projects = [];
  final List<CertificationItem> _certifications = [];
  final List<LanguageItem> _languages = [];

  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nameController = TextEditingController(text: d?.fullName ?? '');
    _titleController = TextEditingController(text: d?.professionalTitle ?? '');
    _phoneController = TextEditingController(text: d?.phone ?? '');
    _emailController = TextEditingController(text: d?.email ?? '');
    _locationController = TextEditingController(text: d?.location ?? '');
    _linkedInController = TextEditingController(text: d?.linkedIn ?? '');
    _websiteController = TextEditingController(text: d?.website ?? '');
    _summaryController = TextEditingController(text: d?.summary ?? '');

    if (d != null) {
      _experiences.addAll(d.experiences);
      _education.addAll(d.education);
      _skills.addAll(d.skills);
      _projects.addAll(d.projects);
      _certifications.addAll(d.certifications);
      _languages.addAll(d.languages);
    } else {
      // Provide clean default sample starter items
      _skills.addAll([
        'Project Management',
        'Team Leadership',
        'Problem Solving',
        'Communication',
      ]);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _linkedInController.dispose();
    _websiteController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  ResumeData _buildResumeData() {
    return ResumeData(
      fullName: _nameController.text.trim(),
      professionalTitle: _titleController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      location: _locationController.text.trim(),
      linkedIn: _linkedInController.text.trim(),
      website: _websiteController.text.trim(),
      summary: _summaryController.text.trim(),
      experiences: _experiences,
      education: _education,
      skills: _skills,
      projects: _projects,
      certifications: _certifications,
      languages: _languages,
    );
  }

  Future<void> _generatePdf() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Please fill in required fields marked with *'),
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final resumeData = _buildResumeData();
      final file = await CareerPdfService.instance.generateResumePdf(resumeData);

      if (!mounted) return;
      setState(() => _isGenerating = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CareerDocumentPreviewView(
            file: file,
            title: '${resumeData.fullName} - CV',
            documentType: 'CV / Resume',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Error generating PDF: $e'),
        ),
      );
    }
  }

  void _showPreviewDialog() {
    final resume = _buildResumeData();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1A24) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CV Summary Preview',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  Text(
                    resume.fullName.isEmpty ? 'Your Full Name' : resume.fullName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                  if (resume.professionalTitle.isNotEmpty)
                    Text(
                      resume.professionalTitle,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (resume.phone.isNotEmpty) resume.phone,
                      if (resume.email.isNotEmpty) resume.email,
                      if (resume.location.isNotEmpty) resume.location,
                    ].join(' • '),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  if (resume.summary.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'SUMMARY',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resume.summary,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                  if (resume.experiences.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'EXPERIENCE',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    ...resume.experiences.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${e.jobTitle} at ${e.company}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            if (e.startDate.isNotEmpty || e.endDate.isNotEmpty)
                              Text('${e.startDate} - ${e.endDate}',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[500])),
                            if (e.description.isNotEmpty)
                              Text(e.description,
                                  style: const TextStyle(
                                      fontSize: 12, height: 1.3)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (resume.education.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'EDUCATION',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    ...resume.education.map(
                      (ed) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${ed.degree}, ${ed.institution}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            if (ed.startYear.isNotEmpty ||
                                ed.endYear.isNotEmpty)
                              Text('${ed.startYear} - ${ed.endYear}',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (resume.skills.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'SKILLS',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: resume.skills
                          .map((s) => Chip(
                                label: Text(s,
                                    style: const TextStyle(fontSize: 11.5)),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _generatePdf();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Generate PDF Now'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // SECTION BUILDERS
  // ===========================================================================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF211B28) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2638) : const Color(0xFFECE4F5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryPurple, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF261E2E),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const Divider(height: 22),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool requiredField = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: requiredField
            ? (val) {
                if (val == null || val.trim().isEmpty) {
                  return '$label is required';
                }
                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: requiredField ? '$label *' : label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF382C43) : const Color(0xFFD6C8E6),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppTheme.primaryPurple, width: 1.8),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // EXPERIENCE DIALOG
  // ===========================================================================

  void _showExperienceDialog([WorkExperience? existing, int? index]) {
    final titleCtrl = TextEditingController(text: existing?.jobTitle ?? '');
    final companyCtrl = TextEditingController(text: existing?.company ?? '');
    final startCtrl = TextEditingController(text: existing?.startDate ?? '');
    final endCtrl = TextEditingController(text: existing?.endDate ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(existing == null ? 'Add Experience' : 'Edit Experience'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Job Title *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: companyCtrl,
                decoration: const InputDecoration(labelText: 'Company *'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(labelText: 'Start Date (e.g. 2021)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      decoration: const InputDecoration(labelText: 'End Date (or Present)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description / Achievements'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty ||
                  companyCtrl.text.trim().isEmpty) {
                return;
              }
              setState(() {
                final item = WorkExperience(
                  jobTitle: titleCtrl.text.trim(),
                  company: companyCtrl.text.trim(),
                  startDate: startCtrl.text.trim(),
                  endDate: endCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
                if (index != null) {
                  _experiences[index] = item;
                } else {
                  _experiences.add(item);
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EDUCATION DIALOG
  // ===========================================================================

  void _showEducationDialog([EducationItem? existing, int? index]) {
    final degreeCtrl = TextEditingController(text: existing?.degree ?? '');
    final instCtrl = TextEditingController(text: existing?.institution ?? '');
    final startCtrl = TextEditingController(text: existing?.startYear ?? '');
    final endCtrl = TextEditingController(text: existing?.endYear ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(existing == null ? 'Add Education' : 'Edit Education'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: degreeCtrl,
                decoration: const InputDecoration(labelText: 'Degree / Certificate *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: instCtrl,
                decoration: const InputDecoration(labelText: 'Institution / University *'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(labelText: 'Start Year'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      decoration: const InputDecoration(labelText: 'End Year'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (degreeCtrl.text.trim().isEmpty) return;
              setState(() {
                final item = EducationItem(
                  degree: degreeCtrl.text.trim(),
                  institution: instCtrl.text.trim(),
                  startYear: startCtrl.text.trim(),
                  endYear: endCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
                if (index != null) {
                  _education[index] = item;
                } else {
                  _education.add(item);
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PROJECT DIALOG
  // ===========================================================================

  void _showProjectDialog([ProjectItem? existing, int? index]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final techCtrl = TextEditingController(text: existing?.technologies ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(existing == null ? 'Add Project' : 'Edit Project'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Project Name *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: techCtrl,
                decoration: const InputDecoration(labelText: 'Technologies (e.g. Flutter, Firebase)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() {
                final item = ProjectItem(
                  name: nameCtrl.text.trim(),
                  technologies: techCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
                if (index != null) {
                  _projects[index] = item;
                } else {
                  _projects.add(item);
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CERTIFICATION DIALOG
  // ===========================================================================

  void _showCertDialog([CertificationItem? existing, int? index]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final orgCtrl = TextEditingController(text: existing?.organization ?? '');
    final dateCtrl = TextEditingController(text: existing?.date ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(existing == null ? 'Add Certification' : 'Edit Certification'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Certification Name *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: orgCtrl,
                decoration: const InputDecoration(labelText: 'Issuing Organization'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(labelText: 'Date / Year'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() {
                final item = CertificationItem(
                  name: nameCtrl.text.trim(),
                  organization: orgCtrl.text.trim(),
                  date: dateCtrl.text.trim(),
                );
                if (index != null) {
                  _certifications[index] = item;
                } else {
                  _certifications.add(item);
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LANGUAGE DIALOG
  // ===========================================================================

  void _showLanguageDialog([LanguageItem? existing, int? index]) {
    final langCtrl = TextEditingController(text: existing?.language ?? '');
    String proficiency = existing?.proficiency ?? 'Fluent';
    const proficiencies = ['Native', 'Fluent', 'Professional', 'Intermediate', 'Elementary'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(existing == null ? 'Add Language' : 'Edit Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: langCtrl,
                decoration: const InputDecoration(labelText: 'Language *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: proficiency,
                decoration: const InputDecoration(labelText: 'Proficiency'),
                items: proficiencies
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDlgState(() => proficiency = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (langCtrl.text.trim().isEmpty) return;
                setState(() {
                  final item = LanguageItem(
                    language: langCtrl.text.trim(),
                    proficiency: proficiency,
                  );
                  if (index != null) {
                    _languages[index] = item;
                  } else {
                    _languages.add(item);
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SKILL DIALOG
  // ===========================================================================

  void _showAddSkillDialog() {
    final skillCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Add Skill'),
        content: TextField(
          controller: skillCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Flutter, Data Analysis, Leadership',
          ),
          onSubmitted: (_) {
            final s = skillCtrl.text.trim();
            if (s.isNotEmpty && !_skills.contains(s)) {
              setState(() => _skills.add(s));
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final s = skillCtrl.text.trim();
              if (s.isNotEmpty && !_skills.contains(s)) {
                setState(() => _skills.add(s));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CV / Resume Builder'),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _showPreviewDialog,
            icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
            label: const Text('Preview'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryPurple,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // 1. Personal Information
              _buildSectionCard(
                title: 'Personal Information',
                icon: Icons.person_outline_rounded,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.badge_outlined,
                    requiredField: true,
                    hint: 'e.g. Sarah Jenkins',
                  ),
                  _buildTextField(
                    controller: _titleController,
                    label: 'Professional Title',
                    icon: Icons.work_outline_rounded,
                    requiredField: true,
                    hint: 'e.g. Senior Mobile App Developer',
                  ),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    requiredField: true,
                    keyboardType: TextInputType.phone,
                    hint: 'e.g. +1 (555) 019-2834',
                  ),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    requiredField: true,
                    keyboardType: TextInputType.emailAddress,
                    hint: 'e.g. sarah.jenkins@email.com',
                  ),
                  _buildTextField(
                    controller: _locationController,
                    label: 'Location / City',
                    icon: Icons.location_on_outlined,
                    hint: 'e.g. San Francisco, CA',
                  ),
                  _buildTextField(
                    controller: _linkedInController,
                    label: 'LinkedIn Profile (optional)',
                    icon: Icons.link_rounded,
                    hint: 'e.g. linkedin.com/in/sarahjenkins',
                  ),
                  _buildTextField(
                    controller: _websiteController,
                    label: 'Website / Portfolio (optional)',
                    icon: Icons.language_rounded,
                    hint: 'e.g. https://sarahjenkins.dev',
                  ),
                ],
              ),

              // 2. Summary
              _buildSectionCard(
                title: 'Professional Summary',
                icon: Icons.article_outlined,
                children: [
                  _buildTextField(
                    controller: _summaryController,
                    label: 'About Me / Summary',
                    maxLines: 4,
                    hint:
                        'Highlight your core strengths, achievements, and career background...',
                  ),
                ],
              ),

              // 3. Experience
              _buildSectionCard(
                title: 'Work Experience',
                icon: Icons.business_center_outlined,
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.primaryPurple),
                  onPressed: () => _showExperienceDialog(),
                  tooltip: 'Add Experience',
                ),
                children: [
                  if (_experiences.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No work experience added yet. Tap + to add.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ..._experiences.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final exp = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2436)
                            : const Color(0xFFF7F3FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exp.jobTitle,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  '${exp.company} • ${exp.startDate} - ${exp.endDate.isEmpty ? "Present" : exp.endDate}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showExperienceDialog(exp, idx),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 18),
                            onPressed: () {
                              setState(() => _experiences.removeAt(idx));
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),

              // 4. Education
              _buildSectionCard(
                title: 'Education',
                icon: Icons.school_outlined,
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.primaryPurple),
                  onPressed: () => _showEducationDialog(),
                  tooltip: 'Add Education',
                ),
                children: [
                  if (_education.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No education entries added yet. Tap + to add.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ..._education.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final edu = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2436)
                            : const Color(0xFFF7F3FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  edu.degree,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  '${edu.institution} • ${edu.startYear} - ${edu.endYear}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showEducationDialog(edu, idx),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 18),
                            onPressed: () {
                              setState(() => _education.removeAt(idx));
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),

              // 5. Skills
              _buildSectionCard(
                title: 'Skills & Competencies',
                icon: Icons.psychology_outlined,
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.primaryPurple),
                  onPressed: _showAddSkillDialog,
                  tooltip: 'Add Skill',
                ),
                children: [
                  if (_skills.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No skills added. Tap + to add professional skills.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _skills
                        .map(
                          (skill) => Chip(
                            label: Text(skill),
                            deleteIcon: const Icon(Icons.close_rounded, size: 16),
                            onDeleted: () {
                              setState(() => _skills.remove(skill));
                            },
                            backgroundColor: isDark
                                ? const Color(0xFF2C2436)
                                : const Color(0xFFF1E9FA),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),

              // 6. Projects
              _buildSectionCard(
                title: 'Key Projects',
                icon: Icons.code_rounded,
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.primaryPurple),
                  onPressed: () => _showProjectDialog(),
                  tooltip: 'Add Project',
                ),
                children: [
                  if (_projects.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No projects added. Tap + to showcase your work.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ..._projects.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final proj = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2436)
                            : const Color(0xFFF7F3FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  proj.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                if (proj.technologies.isNotEmpty)
                                  Text(
                                    proj.technologies,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.primaryPurple),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showProjectDialog(proj, idx),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 18),
                            onPressed: () {
                              setState(() => _projects.removeAt(idx));
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),

              // 7. Certifications
              _buildSectionCard(
                title: 'Certifications',
                icon: Icons.verified_outlined,
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.primaryPurple),
                  onPressed: () => _showCertDialog(),
                  tooltip: 'Add Certification',
                ),
                children: [
                  if (_certifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No certifications added. Tap + to add credentials.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ..._certifications.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final cert = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2436)
                            : const Color(0xFFF7F3FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cert.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  '${cert.organization} ${cert.date.isNotEmpty ? "• ${cert.date}" : ""}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showCertDialog(cert, idx),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 18),
                            onPressed: () {
                              setState(() => _certifications.removeAt(idx));
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),

              // 8. Languages
              _buildSectionCard(
                title: 'Languages',
                icon: Icons.translate_rounded,
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.primaryPurple),
                  onPressed: () => _showLanguageDialog(),
                  tooltip: 'Add Language',
                ),
                children: [
                  if (_languages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No languages added. Tap + to add languages.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ..._languages.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final lang = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2436)
                            : const Color(0xFFF7F3FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${lang.language} (${lang.proficiency})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showLanguageDialog(lang, idx),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent, size: 18),
                            onPressed: () {
                              setState(() => _languages.removeAt(idx));
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),

              const SizedBox(height: 12),

              // Submit & Generate Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generatePdf,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 22),
                  label: Text(
                    _isGenerating ? 'Generating PDF...' : 'Generate CV (PDF)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
