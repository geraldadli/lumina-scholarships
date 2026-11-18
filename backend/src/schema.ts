import type { Timestamp } from 'firebase-admin/firestore';

// Cermin TypeScript dari docs/firestore-contract.md. Ubah keduanya bersamaan.

export const COLLECTIONS = {
  scholarships: 'scholarships',
  sources: 'sources',
  syncLogs: 'sync_logs',
  users: 'users',
  savedScholarships: 'saved_scholarships',
} as const;

/** Beasiswa dianggap mendesak jika sisa waktu <= 14 hari. */
export const URGENT_WINDOW_DAYS = 14;

export type EducationLevel = 'undergraduate' | 'masters' | 'phd';
export type ScholarshipStatus = 'active' | 'closed';
export type SourceRunStatus = 'seeded' | 'baseline' | 'unchanged' | 'updated' | 'error';
export type SyncStatus = 'success' | 'partial' | 'failed';

export interface Requirement {
  id: string;
  label: string;
}

export type VerificationStatus = 'verified' | 'pending';
/** Nilai `verifiedBy` dari tim Research untuk data yang belum dicek manusia. */
export const VERIFICATION_PENDING = 'pending-human-review';

export interface Scholarship {
  title: string;
  provider: string;
  description?: string;
  fundingType: 'full' | 'partial';
  educationLevels: EducationLevel[];
  eligibleCitizenships: string[];
  hostCountries: string[];
  /** `[]` = bidang belum diumumkan → klien JANGAN menyaring berdasarkan field ini. `["ALL"]` = semua bidang. */
  fieldsOfStudy: string[];
  minGpa?: number | null;
  languageRequirement?: string | null;
  openDate?: Timestamp | null;
  deadline?: Timestamp;
  status: ScholarshipStatus;
  isUrgent?: boolean;
  requirements?: Requirement[];
  benefits?: string[];
  sourceUrl: string;
  notes?: string | null;
  verificationStatus?: VerificationStatus;
  verifiedBy?: string | null;
  lastVerifiedAt?: Timestamp | null;
  lastChangeSummary?: string | null;
  /** Hash field yang terlihat user; dipakai importer untuk memutuskan kapan `updatedAt` naik. */
  contentHash?: string;
  /** Hash seluruh record JSON (termasuk metadata verifikasi). */
  recordHash?: string;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
  lastCheckedAt?: Timestamp;
}

/** Bentuk satu record di `backend/data/scholarships.json` (format tim Research). */
export interface ResearchScholarship {
  id: string;
  title: string;
  provider: string;
  fundingType: 'full' | 'partial';
  educationLevels: EducationLevel[];
  eligibleCitizenships: string[];
  hostCountries: string[];
  fieldsOfStudy: string[];
  minGpa?: number | null;
  languageRequirement?: string | null;
  /** `YYYY-MM-DD` (dibaca sebagai 00:00 WIB) atau ISO 8601 dengan zona waktu. */
  openDate?: string | null;
  /** `YYYY-MM-DD` (dibaca sebagai 23:59:59 WIB) atau ISO 8601 dengan zona waktu. */
  deadline: string;
  status: ScholarshipStatus;
  sourceUrl: string;
  description: string;
  requirements?: string[];
  benefits?: string[];
  lastVerified?: string | null;
  verifiedBy?: string | null;
  notes?: string | null;
  /** Opsional: ringkasan 1 kalimat untuk "Track updates" saat record diubah. */
  changeSummary?: string | null;
}

export interface ImportSummary {
  total: number;
  created: string[];
  contentUpdated: string[];
  metadataUpdated: string[];
  unchanged: string[];
  /** Dokumen di Firestore yang tidak ada di JSON (tidak dihapus otomatis). */
  notInJson: string[];
  warnings: string[];
}

export interface Source {
  scholarshipId?: string;
  name: string;
  url: string;
  /** Regex (string) untuk membuang teks dinamis sebelum hashing, mis. jam/tanggal hari ini. */
  ignorePatterns?: string[];
  lastContentHash?: string;
  previousContentHash?: string;
  lastRunStatus?: SourceRunStatus;
  needsReview?: boolean;
  lastChangedAt?: Timestamp;
  lastRunAt?: Timestamp;
  lastHttpStatus?: number | null;
  lastError?: string | null;
  consecutiveErrors?: number;
}

export interface SourceCheckSummary {
  checked: number;
  baseline: number;
  unchanged: number;
  updated: number;
  errors: number;
  changedSourceIds: string[];
  errorDetails: { sourceId: string; message: string }[];
}

export interface DeadlineSummary {
  scanned: number;
  closed: string[];
  urgentOn: string[];
  urgentOff: string[];
  skippedNoDeadline: string[];
}
