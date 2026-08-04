import { base } from '$app/paths';
import Papa from 'papaparse';
import type { PeriodType } from '$lib/data';

export type FootRiskRow = {
	period_type: PeriodType;
	fiscal_year_be: number;
	period_order: number;
	period_label: string;
	risk_code: string;
	risk_name: string;
	risk_order: number;
	total_hn: number;
};

const FOOT_RISK_CSV_URL = `${base}/foot_risk_summary.csv`;
const ALLOWED_PERIOD_TYPES = new Set<PeriodType>(['ปีงบประมาณ', 'ไตรมาส']);
const REQUIRED_COLUMNS = [
	'period_type',
	'fiscal_year_be',
	'period_order',
	'period_label',
	'risk_code',
	'risk_name',
	'risk_order',
	'total_hn'
] as const;

function toNumber(value: unknown): number {
	const numberValue = Number(String(value ?? '').replace(/,/g, '').trim());
	return Number.isFinite(numberValue) ? numberValue : 0;
}

function cleanText(value: unknown): string {
	return value === null || value === undefined ? '' : String(value).trim();
}

function assertRequiredColumns(fields: string[] | undefined): void {
	const availableFields = new Set(fields ?? []);
	const missingFields = REQUIRED_COLUMNS.filter((field) => !availableFields.has(field));
	if (missingFields.length > 0) {
		throw new Error(`โครงสร้างไฟล์ความเสี่ยงเท้าไม่ครบ: ${missingFields.join(', ')}`);
	}
}

export async function loadFootRiskSummary(): Promise<FootRiskRow[]> {
	const response = await fetch(`${FOOT_RISK_CSV_URL}?v=${Date.now()}`, { cache: 'no-store' });
	if (!response.ok) {
		throw new Error(`โหลดข้อมูลความเสี่ยงเท้าไม่สำเร็จ (HTTP ${response.status})`);
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
		console.warn('พบแถว CSV ความเสี่ยงเท้าที่อ่านไม่สมบูรณ์บางส่วน:', parsed.errors);
	}

	return parsed.data.flatMap((row) => {
		const periodType = cleanText(row.period_type) as PeriodType;
		const fiscalYear = toNumber(row.fiscal_year_be);
		const riskCode = cleanText(row.risk_code);

		if (!ALLOWED_PERIOD_TYPES.has(periodType) || fiscalYear <= 0 || riskCode === '') {
			return [];
		}

		return [
			{
				period_type: periodType,
				fiscal_year_be: fiscalYear,
				period_order: toNumber(row.period_order),
				period_label: cleanText(row.period_label),
				risk_code: riskCode,
				risk_name: cleanText(row.risk_name),
				risk_order: toNumber(row.risk_order),
				total_hn: toNumber(row.total_hn)
			}
		];
	});
}
