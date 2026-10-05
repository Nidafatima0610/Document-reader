import 'dart:convert';

/// Work experience entry for Resume / CV
class WorkExperience {
  String jobTitle;
  String company;
  String startDate;
  String endDate;
  String description;

  WorkExperience({
    this.jobTitle = '',
    this.company = '',
    this.startDate = '',
    this.endDate = '',
    this.description = '',
  });

  Map<String, dynamic> toMap() => {
        'jobTitle': jobTitle,
        'company': company,
        'startDate': startDate,
        'endDate': endDate,
        'description': description,
      };

  factory WorkExperience.fromMap(Map<String, dynamic> map) => WorkExperience(
        jobTitle: map['jobTitle'] ?? '',
        company: map['company'] ?? '',
        startDate: map['startDate'] ?? '',
        endDate: map['endDate'] ?? '',
        description: map['description'] ?? '',
      );
}

/// Education entry for Resume / CV
class EducationItem {
  String degree;
  String institution;
  String startYear;
  String endYear;
  String description;

  EducationItem({
    this.degree = '',
    this.institution = '',
    this.startYear = '',
    this.endYear = '',
    this.description = '',
  });

  Map<String, dynamic> toMap() => {
        'degree': degree,
        'institution': institution,
        'startYear': startYear,
        'endYear': endYear,
        'description': description,
      };

  factory EducationItem.fromMap(Map<String, dynamic> map) => EducationItem(
        degree: map['degree'] ?? '',
        institution: map['institution'] ?? '',
        startYear: map['startYear'] ?? '',
        endYear: map['endYear'] ?? '',
        description: map['description'] ?? '',
      );
}

/// Project item for Resume / CV
class ProjectItem {
  String name;
  String description;
  String technologies;

  ProjectItem({
    this.name = '',
    this.description = '',
    this.technologies = '',
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'technologies': technologies,
      };

  factory ProjectItem.fromMap(Map<String, dynamic> map) => ProjectItem(
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        technologies: map['technologies'] ?? '',
      );
}

/// Certification item for Resume / CV
class CertificationItem {
  String name;
  String organization;
  String date;

  CertificationItem({
    this.name = '',
    this.organization = '',
    this.date = '',
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'organization': organization,
        'date': date,
      };

  factory CertificationItem.fromMap(Map<String, dynamic> map) =>
      CertificationItem(
        name: map['name'] ?? '',
        organization: map['organization'] ?? '',
        date: map['date'] ?? '',
      );
}

/// Language proficiency entry for Resume / CV
class LanguageItem {
  String language;
  String proficiency;

  LanguageItem({
    this.language = '',
    this.proficiency = 'Fluent',
  });

  Map<String, dynamic> toMap() => {
        'language': language,
        'proficiency': proficiency,
      };

  factory LanguageItem.fromMap(Map<String, dynamic> map) => LanguageItem(
        language: map['language'] ?? '',
        proficiency: map['proficiency'] ?? 'Fluent',
      );
}

/// Complete CV / Resume Data Model
class ResumeData {
  String fullName;
  String professionalTitle;
  String phone;
  String email;
  String location;
  String linkedIn;
  String website;
  String summary;

  List<WorkExperience> experiences;
  List<EducationItem> education;
  List<String> skills;
  List<ProjectItem> projects;
  List<CertificationItem> certifications;
  List<LanguageItem> languages;

  ResumeData({
    this.fullName = '',
    this.professionalTitle = '',
    this.phone = '',
    this.email = '',
    this.location = '',
    this.linkedIn = '',
    this.website = '',
    this.summary = '',
    List<WorkExperience>? experiences,
    List<EducationItem>? education,
    List<String>? skills,
    List<ProjectItem>? projects,
    List<CertificationItem>? certifications,
    List<LanguageItem>? languages,
  })  : experiences = experiences ?? [],
        education = education ?? [],
        skills = skills ?? [],
        projects = projects ?? [],
        certifications = certifications ?? [],
        languages = languages ?? [];

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'professionalTitle': professionalTitle,
        'phone': phone,
        'email': email,
        'location': location,
        'linkedIn': linkedIn,
        'website': website,
        'summary': summary,
        'experiences': experiences.map((e) => e.toMap()).toList(),
        'education': education.map((e) => e.toMap()).toList(),
        'skills': skills,
        'projects': projects.map((p) => p.toMap()).toList(),
        'certifications': certifications.map((c) => c.toMap()).toList(),
        'languages': languages.map((l) => l.toMap()).toList(),
      };

  String toJson() => jsonEncode(toMap());

  factory ResumeData.fromMap(Map<String, dynamic> map) => ResumeData(
        fullName: map['fullName'] ?? '',
        professionalTitle: map['professionalTitle'] ?? '',
        phone: map['phone'] ?? '',
        email: map['email'] ?? '',
        location: map['location'] ?? '',
        linkedIn: map['linkedIn'] ?? '',
        website: map['website'] ?? '',
        summary: map['summary'] ?? '',
        experiences: (map['experiences'] as List<dynamic>?)
                ?.map((e) => WorkExperience.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
        education: (map['education'] as List<dynamic>?)
                ?.map((e) => EducationItem.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
        skills: (map['skills'] as List<dynamic>?)
                ?.map((s) => s.toString())
                .toList() ??
            [],
        projects: (map['projects'] as List<dynamic>?)
                ?.map((p) => ProjectItem.fromMap(p as Map<String, dynamic>))
                .toList() ??
            [],
        certifications: (map['certifications'] as List<dynamic>?)
                ?.map((c) =>
                    CertificationItem.fromMap(c as Map<String, dynamic>))
                .toList() ??
            [],
        languages: (map['languages'] as List<dynamic>?)
                ?.map((l) => LanguageItem.fromMap(l as Map<String, dynamic>))
                .toList() ??
            [],
      );

  factory ResumeData.fromJson(String source) =>
      ResumeData.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Cover Letter Data Model
class CoverLetterData {
  String applicantName;
  String email;
  String phone;
  String address;
  String date;
  String companyName;
  String hiringManagerName;
  String jobTitle;
  String jobReference;
  String introduction;
  String skillsExperience;
  String whyInterested;
  String closingMessage;

  CoverLetterData({
    this.applicantName = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.date = '',
    this.companyName = '',
    this.hiringManagerName = '',
    this.jobTitle = '',
    this.jobReference = '',
    this.introduction = '',
    this.skillsExperience = '',
    this.whyInterested = '',
    this.closingMessage = '',
  });

  Map<String, dynamic> toMap() => {
        'applicantName': applicantName,
        'email': email,
        'phone': phone,
        'address': address,
        'date': date,
        'companyName': companyName,
        'hiringManagerName': hiringManagerName,
        'jobTitle': jobTitle,
        'jobReference': jobReference,
        'introduction': introduction,
        'skillsExperience': skillsExperience,
        'whyInterested': whyInterested,
        'closingMessage': closingMessage,
      };

  String toJson() => jsonEncode(toMap());

  factory CoverLetterData.fromMap(Map<String, dynamic> map) => CoverLetterData(
        applicantName: map['applicantName'] ?? '',
        email: map['email'] ?? '',
        phone: map['phone'] ?? '',
        address: map['address'] ?? '',
        date: map['date'] ?? '',
        companyName: map['companyName'] ?? '',
        hiringManagerName: map['hiringManagerName'] ?? '',
        jobTitle: map['jobTitle'] ?? '',
        jobReference: map['jobReference'] ?? '',
        introduction: map['introduction'] ?? '',
        skillsExperience: map['skillsExperience'] ?? '',
        whyInterested: map['whyInterested'] ?? '',
        closingMessage: map['closingMessage'] ?? '',
      );

  factory CoverLetterData.fromJson(String source) =>
      CoverLetterData.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Reference Letter Data Model
class ReferenceLetterData {
  String refereeName;
  String refereePosition;
  String organization;
  String contactInfo;
  String date;
  String applicantName;
  String applicantPosition;
  String relationship;
  String durationKnown;
  String strengthsSkills;
  String professionalQualities;
  String additionalComments;

  ReferenceLetterData({
    this.refereeName = '',
    this.refereePosition = '',
    this.organization = '',
    this.contactInfo = '',
    this.date = '',
    this.applicantName = '',
    this.applicantPosition = '',
    this.relationship = '',
    this.durationKnown = '',
    this.strengthsSkills = '',
    this.professionalQualities = '',
    this.additionalComments = '',
  });

  Map<String, dynamic> toMap() => {
        'refereeName': refereeName,
        'refereePosition': refereePosition,
        'organization': organization,
        'contactInfo': contactInfo,
        'date': date,
        'applicantName': applicantName,
        'applicantPosition': applicantPosition,
        'relationship': relationship,
        'durationKnown': durationKnown,
        'strengthsSkills': strengthsSkills,
        'professionalQualities': professionalQualities,
        'additionalComments': additionalComments,
      };

  String toJson() => jsonEncode(toMap());

  factory ReferenceLetterData.fromMap(Map<String, dynamic> map) =>
      ReferenceLetterData(
        refereeName: map['refereeName'] ?? '',
        refereePosition: map['refereePosition'] ?? '',
        organization: map['organization'] ?? '',
        contactInfo: map['contactInfo'] ?? '',
        date: map['date'] ?? '',
        applicantName: map['applicantName'] ?? '',
        applicantPosition: map['applicantPosition'] ?? '',
        relationship: map['relationship'] ?? '',
        durationKnown: map['durationKnown'] ?? '',
        strengthsSkills: map['strengthsSkills'] ?? '',
        professionalQualities: map['professionalQualities'] ?? '',
        additionalComments: map['additionalComments'] ?? '',
      );

  factory ReferenceLetterData.fromJson(String source) =>
      ReferenceLetterData.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
