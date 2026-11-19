import 'package:hybrid_ai/hybrid_ai.dart';

/// Data CONTOH untuk menguji paket di perangkat. App produksi mengambil data ini
/// dari Firestore (`scholarships/{id}` dan `users/{uid}`), lihat docs/firestore-contract.md.
final sampleScholarships = <ScholarshipContext>[
  ScholarshipContext(
    id: 'mext-scholarship-2027',
    title: 'MEXT Scholarship (Monbukagakusho) 2027',
    provider: 'Government of Japan',
    description:
        'Beasiswa penuh pemerintah Jepang mencakup biaya kuliah, tunjangan hidup bulanan, dan tiket pesawat PP.',
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
      RequirementItem(id: 'application-form', label: 'Formulir pendaftaran MEXT'),
      RequirementItem(id: 'transcript', label: 'Transkrip nilai akademik'),
      RequirementItem(id: 'research-plan', label: 'Rencana riset / field of study plan'),
      RequirementItem(id: 'recommendation', label: 'Surat rekomendasi dari universitas'),
      RequirementItem(id: 'language-cert', label: 'Sertifikat bahasa (JLPT atau bahasa Inggris)'),
    ],
    benefits: ['Biaya kuliah penuh', 'Tunjangan bulanan', 'Tiket pesawat pulang-pergi'],
    sourceUrl: 'https://www.id.emb-japan.go.jp/sch.html',
  ),
  ScholarshipContext(
    id: 'australia-awards-2027',
    title: 'Australia Awards Scholarships',
    provider: 'Australian Government (DFAT)',
    description:
        'Beasiswa penuh S2/S3 di Australia untuk WNI: tiket pesawat, tunjangan awal, biaya kuliah penuh, dan biaya hidup.',
    fundingType: 'full',
    educationLevels: ['masters', 'phd'],
    eligibleCitizenships: ['ID'],
    hostCountries: ['AU'],
    fieldsOfStudy: [],
    minGpa: 2.9,
    languageRequirement: 'IELTS 6.5 by the end of pre-departure training',
    openDate: '2026-02-01',
    deadline: '2026-04-30',
    status: 'closed',
    requirements: [
      RequirementItem(id: 'online-application-form', label: 'Online application form'),
      RequirementItem(
        id: 'supporting-documents',
        label: 'Supporting documents listed in the Australia Awards Scholarships Policy Handbook',
      ),
    ],
    benefits: [],
    sourceUrl: 'https://www.australiaawardsindonesia.org/content/158/12/general-requirements?sub=true',
    notes: 'Min GPA: Masters 2.9, PhD 3.0. Intake berikutnya diperkirakan dibuka sekitar Feb 2027.',
  ),
];

/// Profil contoh hasil "Set preferences".
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
  'Apa syarat bahasa untuk beasiswa ini?',
  'Kapan batas pendaftarannya?',
  'Apakah profil saya cocok? Jelaskan singkat.',
  'Apa saja yang ditanggung beasiswa ini?',
];
