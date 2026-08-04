import { base } from '$app/paths';
import Papa from 'papaparse';

export type PeriodType = 'ปีงบประมาณ' | 'ไตรมาส';

export type NcdIndicator = {
	period_type: PeriodType;
	fiscal_year_be: number;
	period_order: number;
	period_label: string;
	indicator_no: number;
	indicator_name: string;
	target_text: string;
	target_type: string;
	target_value: number;
	numerator: number | null;
	denominator: number | null;
	actual_percent: number | null;
	status: string;
	gap_from_target: number | null;
};

const NCD_CSV_URL = `${base}/ncd_indicator_summary.csv`;
const ALLOWED_PERIOD_TYPES = new Set<PeriodType>(['ปีงบประมาณ', 'ไตรมาส']);
const REQUIRED_COLUMNS = [
	'period_type',
	'fiscal_year_be',
	'period_order',
	'period_label',
	'indicator_no',
	'indicator_name',
	'target_text',
	'target_type',
	'target_value',
	'numerator',
	'denominator',
	'actual_percent',
	'status',
	'gap_from_target'
] as const;

function toNumber(value: unknown): number {
	const numberValue = Number(String(value ?? '').replace(/,/g, '').trim());
	return Number.isFinite(numberValue) ? numberValue : 0;
}

function toNullableNumber(value: unknown): number | null {
	if (value === null || value === undefined) return null;
	const text = String(value).trim();
	if (text === '' || text === '-') return null;
	const numberValue = Number(text.replace(/,/g, ''));
	return Number.isFinite(numberValue) ? numberValue : null;
}

function cleanText(value: unknown): string {
	return value === null || value === undefined ? '' : String(value).trim();
}

function assertRequiredColumns(fields: string[] | undefined): void {
	const availableFields = new Set(fields ?? []);
	const missingFields = REQUIRED_COLUMNS.filter((field) => !availableFields.has(field));
	if (missingFields.length > 0) {
		throw new Error(`โครงสร้างไฟล์ตัวชี้วัดไม่ครบ: ${missingFields.join(', ')}`);
	}
}

export async function loadNcdIndicators(): Promise<NcdIndicator[]> {
	const response = await fetch(`${NCD_CSV_URL}?v=${Date.now()}`, { cache: 'no-store' });
	if (!response.ok) {
		throw new Error(`โหลดข้อมูลตัวชี้วัดไม่สำเร็จ (HTTP ${response.status})`);
	}

	const csvText = await response.text();
	if (!csvText.trim()) return [];

	const parsed = Papa.parse<Record<string, string>>(csvText, {
		header: true,
		skipEmptyLines: 'greedy',
		transformHeader: (header) => header.replace(/^\uFEFF/, '').trim()
	});

	assertRequiredColumns(parsed.meta.fields);

	if (parsed.errors.length > 0) {
		console.warn('พบแถว CSV ที่อ่านไม่สมบูรณ์บางส่วน:', parsed.errors);
	}

	return parsed.data.flatMap((row) => {
		const periodType = cleanText(row.period_type) as PeriodType;
		const fiscalYear = toNumber(row.fiscal_year_be);
		const indicatorNo = toNumber(row.indicator_no);

		if (!ALLOWED_PERIOD_TYPES.has(periodType) || fiscalYear <= 0 || indicatorNo <= 0) {
			return [];
		}

		return [
			{
				period_type: periodType,
				fiscal_year_be: fiscalYear,
				period_order: toNumber(row.period_order),
				period_label: cleanText(row.period_label),
				indicator_no: indicatorNo,
				indicator_name: cleanText(row.indicator_name),
				target_text: cleanText(row.target_text),
				target_type: cleanText(row.target_type),
				target_value: toNumber(row.target_value),
				numerator: toNullableNumber(row.numerator),
				denominator: toNullableNumber(row.denominator),
				actual_percent: toNullableNumber(row.actual_percent),
				status: cleanText(row.status),
				gap_from_target: toNullableNumber(row.gap_from_target)
			}
		];
	});
}
