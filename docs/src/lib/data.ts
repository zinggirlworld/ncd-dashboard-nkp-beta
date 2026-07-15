import { base } from '$app/paths';
import Papa from 'papaparse';

export type NcdIndicator = {
	period_type: string;
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

function toNumber(value: unknown): number {
	const n = Number(value);
	return Number.isFinite(n) ? n : 0;
}

function toNullableNumber(value: unknown): number | null {
	if (value === null || value === undefined) return null;

	const text = String(value).trim();

	if (text === '' || text === '-') return null;

	const n = Number(text.replace(/,/g, ''));

	return Number.isFinite(n) ? n : null;
}

function cleanText(value: unknown): string {
	if (value === null || value === undefined) return '';

	return String(value).trim();
}

export async function loadNcdIndicators(): Promise<NcdIndicator[]> {
	const response = await fetch(NCD_CSV_URL, {
		cache: 'no-store'
	});

	if (!response.ok) {
		throw new Error(`โหลดข้อมูล ncd_indicator_summary.csv ไม่สำเร็จ: ${response.status}`);
	}

	const csvText = await response.text();

	if (!csvText.trim()) {
		return [];
	}

	const parsed = Papa.parse<Record<string, string>>(csvText, {
		header: true,
		skipEmptyLines: true
	});

	if (parsed.errors.length > 0) {
		console.warn('NCD indicator CSV parse errors:', parsed.errors);
	}

	return parsed.data
		.map((row) => ({
			period_type: cleanText(row.period_type),
			fiscal_year_be: toNumber(row.fiscal_year_be),
			period_order: toNumber(row.period_order),
			period_label: cleanText(row.period_label),
			indicator_no: toNumber(row.indicator_no),
			indicator_name: cleanText(row.indicator_name),
			target_text: cleanText(row.target_text),
			target_type: cleanText(row.target_type),
			target_value: toNumber(row.target_value),
			numerator: toNullableNumber(row.numerator),
			denominator: toNullableNumber(row.denominator),
			actual_percent: toNullableNumber(row.actual_percent),
			status: cleanText(row.status),
			gap_from_target: toNullableNumber(row.gap_from_target)
		}))
		.filter((row) => row.fiscal_year_be > 0 && row.indicator_no > 0);
}
