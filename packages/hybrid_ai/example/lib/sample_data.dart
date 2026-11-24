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
    provider: 'Australian Government (DFAT), managed by Australia Awards in Indonesia',
    description:
        'Fully funded Masters or PhD study at an Australian university for Indonesian citizens. '
        'Covers return air travel, a one-off establishment allowance, full tuition fees and a '
        'contribution to living expenses.',
    fundingType: 'full',
    educationLevels: ['masters', 'phd'],
    eligibleCitizenships: ['ID'],
    hostCountries: ['AU'],
    // Priority fields: focus areas of the Australia-Indonesia Development Partnership Plan 2024-2028.
    fieldsOfStudy: [
      'economic governance',
      'trade and investment',
      'education',
      'research and innovation',
      'secure jobs',
      'digital transformation',
      'health',
      'social protection',
      'decentralised governance and basic service delivery',
      'GEDSI (gender equality, disability and social inclusion)',
      'civil society',
      'scholarships',
      'energy transition and climate and infrastructure partnership',
      'animal/human health services and biosecurity',
    ],
    minGpa: 2.9,
    languageRequirement:
        'Required at application. Masters: IELTS 6.0 / TOEFL iBT 80 / TOEFL ITP 552 / PTE 56 '
        '(equity target groups: IELTS 4.5 / iBT 33 / ITP 425 / PTE 32). PhD: IELTS 6.5 / iBT 88 / '
        'ITP 570 / PTE 61 (Government of Indonesia and equity target groups: IELTS 6.0 / iBT 80 / '
        'ITP 552 / PTE 56)',
    openDate: '2027-02-01',
    deadline: '2027-04-28',
    status: 'active',
    requirements: [
      RequirementItem(
        id: 'minimum-gpa-masters-2-9-phd-3-0-equity-target-gr',
        label: 'Minimum GPA: Masters 2.9, PhD 3.0 (equity target groups 2.75 for both)',
      ),
      RequirementItem(id: 'online-application-form', label: 'Online application form'),
      RequirementItem(
        id: 'supporting-documents-listed-in-the-australia-awa',
        label: 'Supporting documents listed in the Australia Awards Scholarships Policy Handbook',
      ),
      RequirementItem(
        id: 'targeted-categories-only-sk-pns-ktp-from-an-equi',
        label: 'Targeted categories only: SK PNS, KTP from an equity-target province, or letter confirming disability status',
      ),
    ],
    benefits: ['Full tuition fees', 'Return air travel', 'One-off establishment allowance', 'Contribution to living expenses'],
    sourceUrl: 'https://www.australiaawardsindonesia.org/content/158/12/general-requirements?sub=true',
    notes:
        '2028 intake. Deadline 28 Apr 2027, 11:00 WIB. Must apply for a course in the priority '
        'fields of study (focus areas of the Australia-Indonesia Development Partnership Plan '
        '2024-2028). Min GPA: Masters 2.9, PhD 3.0; equity target groups 2.75. minGpa stays at the '
        'Masters value (2.9) until the app can show different GPA thresholds per level and '
        'category; the full breakdown is in requirements. English test validity date differs '
        'between the General Requirements page (valid on 1 Jan 2027) and the Supporting Documents '
        'page (valid on 1 Jan 2028); confirm with AAI before stating it.',
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
