import 'package:all_documents_reader/core/theme/app_theme.dart';
import 'package:all_documents_reader/models/career_models.dart';
import 'package:all_documents_reader/services/career_pdf_service.dart';
import 'package:all_documents_reader/views/career_document_preview_view.dart';
import 'package:flutter/material.dart';

/// Professional Offline Cover Letter Generator
class CareerCoverLetterView extends StatefulWidget {
  final CoverLetterData? initialData;

  const CareerCoverLetterView({super.key, this.initialData});

  @override
  State<CareerCoverLetterView> createState() => _CareerCoverLetterViewState();
}

class _CareerCoverLetterViewState extends State<CareerCoverLetterView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _dateController;
  late TextEditingController _companyController;
  late TextEditingController _managerController;
  late TextEditingController _jobTitleController;
  late TextEditingController _jobRefController;
  late TextEditingController _introController;
  late TextEditingController _skillsController;
  late TextEditingController _whyInterestedController;
  late TextEditingController _closingController;

  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nameController = TextEditingController(text: d?.applicantName ?? '');
    _emailController = TextEditingController(text: d?.email ?? '');
    _phoneController = TextEditingController(text: d?.phone ?? '');
    _addressController = TextEditingController(text: d?.address ?? '');
    _dateController = TextEditingController(
      text: d?.date.isNotEmpty == true ? d!.date : _defaultTodayDate(),
    );
    _companyController = TextEditingController(text: d?.companyName ?? '');
    _managerController = TextEditingController(text: d?.hiringManagerName ?? '');
    _jobTitleController = TextEditingController(text: d?.jobTitle ?? '');
    _jobRefController = TextEditingController(text: d?.jobReference ?? '');

    _introController = TextEditingController(
      text: d?.introduction.isNotEmpty == true
          ? d!.introduction
          : 'I am writing to express my enthusiastic interest in the position. With my background, relevant expertise, and dedication to excellence, I am confident in my ability to make an immediate, positive contribution to your team.',
    );

    _skillsController = TextEditingController(
      text: d?.skillsExperience.isNotEmpty == true
          ? d!.skillsExperience
          : 'Throughout my career, I have developed a proven track record of solving complex problems, delivering reliable results on schedule, and collaborating effectively across diverse teams. My core strengths directly align with the qualifications you are seeking.',
    );

    _whyInterestedController = TextEditingController(
      text: d?.whyInterested.isNotEmpty == true
          ? d!.whyInterested
          : 'I have long admired your organization\'s innovative approach, high standards, and culture of continuous improvement. The opportunity to contribute to your ongoing success while expanding my professional impact is deeply compelling to me.',
    );

    _closingController = TextEditingController(
      text: d?.closingMessage.isNotEmpty == true
          ? d!.closingMessage
          : 'Thank you for your time and consideration of my application. I look forward to the possibility of discussing how my experience and skills can best support your strategic goals.',
    );
  }

  String _defaultTodayDate() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _dateController.dispose();
    _companyController.dispose();
    _managerController.dispose();
    _jobTitleController.dispose();
    _jobRefController.dispose();
    _introController.dispose();
    _skillsController.dispose();
    _whyInterestedController.dispose();
    _closingController.dispose();
    super.dispose();
  }

  CoverLetterData _buildData() {
    return CoverLetterData(
      applicantName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      date: _dateController.text.trim(),
      companyName: _companyController.text.trim(),
      hiringManagerName: _managerController.text.trim(),
      jobTitle: _jobTitleController.text.trim(),
      jobReference: _jobRefController.text.trim(),
      introduction: _introController.text.trim(),
      skillsExperience: _skillsController.text.trim(),
      whyInterested: _whyInterestedController.text.trim(),
      closingMessage: _closingController.text.trim(),
    );
  }

  void _loadStandardTemplate() {
    final role = _jobTitleController.text.trim().isNotEmpty
        ? _jobTitleController.text.trim()
        : 'the advertised role';
    final comp = _companyController.text.trim().isNotEmpty
        ? _companyController.text.trim()
        : 'your company';

    setState(() {
      _introController.text =
          'I am writing to formally apply for the position of $role at $comp. Having closely followed your company\'s achievements, I believe my skills and professional background make me an exceptional fit for your organization.';

      _skillsController.text =
          'In my previous work, I have demonstrated strong analytical capabilities, effective collaboration, and a consistent focus on delivering high-quality outcomes. I bring hands-on experience and a proactive problem-solving mindset that will enable me to deliver immediate value.';

      _whyInterestedController.text =
          'I am particularly drawn to $comp because of your reputation for excellence, innovation, and client satisfaction. I am excited by the prospect of joining a forward-thinking team where I can contribute meaningfully.';

      _closingController.text =
          'Thank you for reviewing my credentials. I welcome the opportunity to speak with you regarding how my background aligns with your requirements. I look forward to your positive response.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Standard template loaded. You can customize paragraphs below.'),
      ),
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
      final data = _buildData();
      final file =
          await CareerPdfService.instance.generateCoverLetterPdf(data);

      if (!mounted) return;
      setState(() => _isGenerating = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CareerDocumentPreviewView(
            file: file,
            title: '${data.applicantName} - Cover Letter',
            documentType: 'Cover Letter',
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
    final d = _buildData();
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
                        'Cover Letter Preview',
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
                    d.applicantName.isEmpty ? 'Your Name' : d.applicantName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                  Text(
                    [d.email, d.phone, d.address]
                        .where((s) => s.isNotEmpty)
                        .join(' • '),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(d.date, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                  if (d.hiringManagerName.isNotEmpty)
                    Text(d.hiringManagerName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (d.companyName.isNotEmpty)
                    Text(d.companyName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (d.jobTitle.isNotEmpty)
                    Text('Regarding: ${d.jobTitle}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryPurple)),
                  const SizedBox(height: 14),
                  Text(
                    d.hiringManagerName.isNotEmpty
                        ? 'Dear ${d.hiringManagerName},'
                        : 'Dear Hiring Team,',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(d.introduction,
                      style: const TextStyle(fontSize: 13, height: 1.45)),
                  const SizedBox(height: 10),
                  Text(d.skillsExperience,
                      style: const TextStyle(fontSize: 13, height: 1.45)),
                  const SizedBox(height: 10),
                  Text(d.whyInterested,
                      style: const TextStyle(fontSize: 13, height: 1.45)),
                  const SizedBox(height: 10),
                  Text(d.closingMessage,
                      style: const TextStyle(fontSize: 13, height: 1.45)),
                  const SizedBox(height: 16),
                  const Text('Sincerely,', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 16),
                  Text(
                    d.applicantName.isEmpty ? 'Your Name' : d.applicantName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                  color: const Color(0xFF1E88E5).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mail_outline_rounded,
                    color: Color(0xFF1E88E5), size: 20),
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
                const BorderSide(color: Color(0xFF1E88E5), width: 1.8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cover Letter Generator'),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _showPreviewDialog,
            icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
            label: const Text('Preview'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1E88E5),
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
              // 1. Applicant Info
              _buildSectionCard(
                title: 'Applicant Information',
                icon: Icons.person_outline_rounded,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Applicant Name',
                    icon: Icons.badge_outlined,
                    requiredField: true,
                    hint: 'e.g. David Miller',
                  ),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    requiredField: true,
                    keyboardType: TextInputType.emailAddress,
                    hint: 'e.g. david.miller@email.com',
                  ),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    requiredField: true,
                    keyboardType: TextInputType.phone,
                    hint: 'e.g. +1 (555) 345-6789',
                  ),
                  _buildTextField(
                    controller: _addressController,
                    label: 'Address / Location (optional)',
                    icon: Icons.location_on_outlined,
                    hint: 'e.g. Chicago, IL',
                  ),
                  _buildTextField(
                    controller: _dateController,
                    label: 'Document Date',
                    icon: Icons.calendar_today_outlined,
                    hint: 'e.g. October 15, 2026',
                  ),
                ],
              ),

              // 2. Company & Job Details
              _buildSectionCard(
                title: 'Company & Position Details',
                icon: Icons.business_outlined,
                children: [
                  _buildTextField(
                    controller: _companyController,
                    label: 'Company Name',
                    icon: Icons.corporate_fare_rounded,
                    requiredField: true,
                    hint: 'e.g. Acme Technologies Corp.',
                  ),
                  _buildTextField(
                    controller: _jobTitleController,
                    label: 'Target Job Title',
                    icon: Icons.work_outline_rounded,
                    requiredField: true,
                    hint: 'e.g. Senior Software Architect',
                  ),
                  _buildTextField(
                    controller: _managerController,
                    label: 'Hiring Manager Name (optional)',
                    icon: Icons.person_search_outlined,
                    hint: 'e.g. Jane Doe (or leave empty for Team)',
                  ),
                  _buildTextField(
                    controller: _jobRefController,
                    label: 'Job Reference / ID (optional)',
                    icon: Icons.tag_rounded,
                    hint: 'e.g. REQ-2026-904',
                  ),
                ],
              ),

              // 3. Letter Content & Paragraphs
              _buildSectionCard(
                title: 'Letter Content & Paragraphs',
                icon: Icons.description_outlined,
                trailing: TextButton.icon(
                  onPressed: _loadStandardTemplate,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: const Text('Load Template',
                      style: TextStyle(fontSize: 12.5)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1E88E5),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                children: [
                  _buildTextField(
                    controller: _introController,
                    label: '1. Introduction',
                    maxLines: 3,
                    hint: 'State the position applied for and initial motivation...',
                  ),
                  _buildTextField(
                    controller: _skillsController,
                    label: '2. Skills & Relevant Experience',
                    maxLines: 4,
                    hint: 'Highlight your top achievements and capabilities...',
                  ),
                  _buildTextField(
                    controller: _whyInterestedController,
                    label: '3. Why You Are Interested',
                    maxLines: 3,
                    hint: 'Explain why you are excited about this company and role...',
                  ),
                  _buildTextField(
                    controller: _closingController,
                    label: '4. Professional Closing',
                    maxLines: 3,
                    hint: 'Express appreciation and call to next steps...',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Generate Button
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
                    _isGenerating ? 'Generating PDF...' : 'Generate Cover Letter (PDF)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
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
