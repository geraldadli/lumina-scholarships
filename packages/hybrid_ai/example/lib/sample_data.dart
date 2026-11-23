import 'package:hybrid_ai/hybrid_ai.dart';

/// SAMPLE data for testing the package on a device. The production app reads this data
/// from Firestore (`scholarships/{id}` and `users/{uid}`), see docs/firestore-contract.md.
final sampleScholarships = <ScholarshipContext>[
  ScholarshipContext(
    id: 'mext-scholarship-2027',
    title: 'MEXT Scholarship (Monbukagakusho) 2027',
    provider: 'Government of Japan',
    description:
        'Full scholarship from the Japanese government covering tuition, a monthly living allowance, and round-trip airfare.',
    fundingType: 'full',
    educationLevels: ['undergraduate', 'masters', 'phd'],
    eligibleCitizenships: ['ID', 'GLOBAL'],
    hostCountries: ['JP'],
    fieldsOfStudy: ['ALL'],
    minGpa: 3.2,
    languageRequirement: 'JLPT N2 / English Proficiency Certificate',
    deadline: '2027-05-10',
    status: 'active',
    requirements: [
      RequirementItem(id: 'application-form', label: 'MEXT application form'),
      RequirementItem(id: 'transcript', label: 'Academic transcript'),
      RequirementItem(id: 'research-plan', label: 'Research plan / field of study plan'),
      RequirementItem(id: 'recommendation', label: 'Recommendation letter from the university'),
      RequirementItem(id: 'language-cert', label: 'Language certificate (JLPT or English)'),
    ],
    benefits: ['Full tuition', 'Monthly allowance', 'Round-trip airfare'],
    sourceUrl: 'https://www.id.emb-japan.go.jp/sch.html',
  ),
  ScholarshipContext(
    id: 'australia-awards-2028',
    title: 'Australia Awards Scholarships',
    provider: 'Australian Government (DFAT)',
    description:
        "Full Master's/PhD scholarship in Australia for Indonesian citizens: airfare, establishment allowance, full tuition, and living costs.",
    fundingType: 'full',
    educationLevels: ['masters', 'phd'],
    eligibleCitizenships: ['ID'],
    hostCountries: ['AU'],
    fieldsOfStudy: [],
    minGpa: 2.9,
    languageRequirement: 'IELTS 6.5 by the end of pre-departure training',
    openDate: '2027-02-01',
    deadline: '2027-04-28',
    status: 'active',
    requirements: [
      RequirementItem(id: 'online-application-form', label: 'Online application form'),
      RequirementItem(
        id: 'supporting-documents',
        label: 'Supporting documents listed in the Australia Awards Scholarships Policy Handbook',
      ),
    ],
    benefits: [],
    sourceUrl: 'https://www.australiaawardsindonesia.org/content/158/12/general-requirements?sub=true',
    notes: '2028 intake. Deadline 28 Apr 2027, 11:00 WIB. Min GPA: Masters 2.9, PhD 3.0.',
  ),
];

/// A sample profile, as produced by "Set preferences".
final sampleStudent = StudentContext(
  educationLevel: 'masters',
  citizenship: 'ID',
  targetCountries: ['JP', 'AU'],
  fieldsOfStudy: ['Computer Science'],
  gpa: 3.45,
  languageSummary: 'IELTS 6.5',
  skills: ['Flutter', 'Machine Learning'],
  experienceYears: 1,
);

const sampleQuestions = <String>[
  'What is the language requirement for this scholarship?',
  'What is the application deadline?',
  'Is my profile a good match? Explain briefly.',
  'What does this scholarship cover?',
];
