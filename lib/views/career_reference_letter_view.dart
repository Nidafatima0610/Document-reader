import 'package:all_documents_reader/models/career_models.dart';
import 'package:all_documents_reader/services/career_pdf_service.dart';
import 'package:all_documents_reader/views/career_document_preview_view.dart';
import 'package:flutter/material.dart';

/// Professional Offline Reference Letter Generator
class CareerReferenceLetterView extends StatefulWidget {
  final ReferenceLetterData? initialData;

  const CareerReferenceLetterView({super.key, this.initialData});

  @override
  State<CareerReferenceLetterView> createState() =>
      _CareerReferenceLetterViewState();
}

class _CareerReferenceLetterViewState extends State<CareerReferenceLetterView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _refereeNameController;
  late TextEditingController _refereePosController;
  late TextEditingController _orgController;
  late TextEditingController _contactController;
  late TextEditingController _dateController;
  late TextEditingController _applicantNameController;
  late TextEditingController _applicantRoleController;
  late TextEditingController _relationshipController;
  late TextEditingController _durationController;
  late TextEditingController _strengthsController;
  late TextEditingController _qualitiesController;
  late TextEditingController _commentsController;

  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _refereeNameController =
        TextEditingController(text: d?.refereeName ?? '');
    _refereePosController =
        TextEditingController(text: d?.refereePosition ?? '');
    _orgController = TextEditingController(text: d?.organization ?? '');
    _contactController = TextEditingController(text: d?.contactInfo ?? '');
    _dateController = TextEditingController(
      text: d?.date.isNotEmpty == true ? d!.date : _defaultTodayDate(),
    );
    _applicantNameController =
        TextEditingController(text: d?.applicantName ?? '');
    _applicantRoleController =
        TextEditingController(text: d?.applicantPosition ?? '');
    _relationshipController =
        TextEditingController(text: d?.relationship ?? 'Direct Supervisor');
    _durationController =
        TextEditingController(text: d?.durationKnown ?? 'over 3 years');

    _strengthsController = TextEditingController(
      text: d?.strengthsSkills.isNotEmpty == true
          ? d!.strengthsSkills
          : 'During their tenure, they demonstrated outstanding technical acumen, exceptional reliability, and proactive initiative. They consistently delivered high-quality work, met stringent deadlines, and handled complex assignments with composure.',
    );

    _qualitiesController = TextEditingController(
      text: d?.professionalQualities.isNotEmpty == true
          ? d!.professionalQualities
          : 'Beyond their technical competencies, they possess exemplary interpersonal skills, a strong work ethic, and an collaborative spirit. They foster positive team morale and communicate ideas with clarity and diplomacy.',
    );

    _commentsController = TextEditingController(
      text: d?.additionalComments.isNotEmpty == true
          ? d!.additionalComments
          : 'They are an asset to any organization they join, and I give them my highest, unreserved recommendation for any prospective position or opportunity.',
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
    _refereeNameController.dispose();
    _refereePosController.dispose();
    _orgController.dispose();
    _contactController.dispose();
    _dateController.dispose();
    _applicantNameController.dispose();
    _applicantRoleController.dispose();
    _relationshipController.dispose();
    _durationController.dispose();
    _strengthsController.dispose();
    _qualitiesController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  ReferenceLetterData _buildData() {
    return ReferenceLetterData(
      refereeName: _refereeNameController.text.trim(),
      refereePosition: _refereePosController.text.trim(),
      organization: _orgController.text.trim(),
      contactInfo: _contactController.text.trim(),
      date: _dateController.text.trim(),
      applicantName: _applicantNameController.text.trim(),
      applicantPosition: _applicantRoleController.text.trim(),
      relationship: _relationshipController.text.trim(),
      durationKnown: _durationController.text.trim(),
      strengthsSkills: _strengthsController.text.trim(),
      professionalQualities: _qualitiesController.text.trim(),
      additionalComments: _commentsController.text.trim(),
    );
  }

  void _loadStandardTemplate() {
    final appName = _applicantNameController.text.trim().isNotEmpty
        ? _applicantNameController.text.trim()
        : 'the candidate';

    setState(() {
      _strengthsController.text =
          '$appName consistently exceeded expectations in problem solving, strategic thinking, and meticulous execution. Their capacity to quickly adapt to new tools and methodologies was invaluable to our organization.';

      _qualitiesController.text =
          'They hold themselves to the highest standards of personal and professional integrity. They are respectful, trustworthy, supportive of colleagues, and handle responsibility with mature confidence.';

      _commentsController.text =
          'I am proud to recommend $appName without reservation. They will undoubtedly bring the same high standard of performance and enthusiasm to your team.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Recommendation template loaded. You can customize paragraphs below.'),
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
          await CareerPdfService.instance.generateReferenceLetterPdf(data);

      if (!mounted) return;
      setState(() => _isGenerating = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CareerDocumentPreviewView(
            file: file,
            title: '${data.applicantName} - Reference Letter',
            documentType: 'Reference Letter',
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
                        'Reference Letter Preview',
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
                    d.refereeName.isEmpty ? 'Referee Name' : d.refereeName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00897B),
                    ),
                  ),
                  Text(
                    [d.refereePosition, d.organization, d.contactInfo]
                        .where((s) => s.isNotEmpty)
                        .join(' • '),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(d.date, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 14),
                  const Text('To Whom It May Concern:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'SUBJECT: RECOMMENDATION FOR ${d.applicantName.toUpperCase()}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF00897B)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'I am pleased to write this recommendation for ${d.applicantName}, who served as ${d.applicantPosition} at ${d.organization}. I have known them as ${d.relationship} for ${d.durationKnown}.',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Text(d.strengthsSkills,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                  const SizedBox(height: 10),
                  Text(d.professionalQualities,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                  if (d.additionalComments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(d.additionalComments,
                        style: const TextStyle(fontSize: 13, height: 1.4)),
                  ],
                  const SizedBox(height: 16),
                  const Text('Sincerely,', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 14),
                  Text(
                    d.refereeName.isEmpty ? 'Referee Name' : d.refereeName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (d.refereePosition.isNotEmpty)
                    Text(d.refereePosition,
                        style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _generatePdf();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
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
                  color: const Color(0xFF00897B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_user_outlined,
                    color: Color(0xFF00897B), size: 20),
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
                const BorderSide(color: Color(0xFF00897B), width: 1.8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reference Letter Generator'),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _showPreviewDialog,
            icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
            label: const Text('Preview'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00897B),
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
              // 1. Referee Info
              _buildSectionCard(
                title: 'Referee (Recommender) Details',
                icon: Icons.person_pin_outlined,
                children: [
                  _buildTextField(
                    controller: _refereeNameController,
                    label: 'Referee Full Name',
                    icon: Icons.badge_outlined,
                    requiredField: true,
                    hint: 'e.g. Dr. Robert Vance',
                  ),
                  _buildTextField(
                    controller: _refereePosController,
                    label: 'Referee Title / Position',
                    icon: Icons.work_outline_rounded,
                    requiredField: true,
                    hint: 'e.g. Engineering Director / Department Head',
                  ),
                  _buildTextField(
                    controller: _orgController,
                    label: 'Organization / Company',
                    icon: Icons.corporate_fare_rounded,
                    requiredField: true,
                    hint: 'e.g. Vance Applied Technologies',
                  ),
                  _buildTextField(
                    controller: _contactController,
                    label: 'Referee Contact (Email / Phone)',
                    icon: Icons.contact_mail_outlined,
                    requiredField: true,
                    hint: 'e.g. robert.vance@company.com • (555) 789-0123',
                  ),
                  _buildTextField(
                    controller: _dateController,
                    label: 'Letter Date',
                    icon: Icons.calendar_today_outlined,
                    hint: 'e.g. October 15, 2026',
                  ),
                ],
              ),

              // 2. Applicant & Context
              _buildSectionCard(
                title: 'Applicant & Association',
                icon: Icons.assignment_ind_outlined,
                children: [
                  _buildTextField(
                    controller: _applicantNameController,
                    label: 'Applicant Full Name',
                    icon: Icons.person_outline_rounded,
                    requiredField: true,
                    hint: 'e.g. Emily Watson',
                  ),
                  _buildTextField(
                    controller: _applicantRoleController,
                    label: 'Applicant Position / Role',
                    icon: Icons.work_outline_rounded,
                    requiredField: true,
                    hint: 'e.g. Senior Product Designer',
                  ),
                  _buildTextField(
                    controller: _relationshipController,
                    label: 'Relationship to Applicant',
                    icon: Icons.group_outlined,
                    requiredField: true,
                    hint: 'e.g. Direct Manager, Research Mentor',
                  ),
                  _buildTextField(
                    controller: _durationController,
                    label: 'Duration Known',
                    icon: Icons.timelapse_rounded,
                    requiredField: true,
                    hint: 'e.g. 4 years (2022 - present)',
                  ),
                ],
              ),

              // 3. Recommendation Content
              _buildSectionCard(
                title: 'Recommendation Statements',
                icon: Icons.format_quote_rounded,
                trailing: TextButton.icon(
                  onPressed: _loadStandardTemplate,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: const Text('Load Template',
                      style: TextStyle(fontSize: 12.5)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00897B),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                children: [
                  _buildTextField(
                    controller: _strengthsController,
                    label: 'Key Strengths & Achievements',
                    maxLines: 4,
                    hint: 'Describe technical capabilities, output, reliability...',
                  ),
                  _buildTextField(
                    controller: _qualitiesController,
                    label: 'Professional Qualities & Character',
                    maxLines: 4,
                    hint: 'Describe integrity, communication, teamwork, leadership...',
                  ),
                  _buildTextField(
                    controller: _commentsController,
                    label: 'Concluding Recommendation',
                    maxLines: 3,
                    hint: 'Final endorsement statement...',
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
                    _isGenerating ? 'Generating PDF...' : 'Generate Reference Letter (PDF)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
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
