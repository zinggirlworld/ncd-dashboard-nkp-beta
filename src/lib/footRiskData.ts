import { base } from '$app/paths';
import Papa from 'papaparse';

export type FootRiskRow = {
	period_type: string;
	fiscal_year_be: number;
	period_order: number;
	period_label: string;
	risk_code: string;
	risk_name: string;
	risk_order: number;
	total_hn: number;
};

const FOOT_RISK_CSV_URL = `${base}/foot_risk_summary.csv`;

function toNumber(value: unknown): number {
	const n = Number(value);
	return Number.isFinite(n) ? n : 0;
}

function cleanText(value: unknown): string {
	if (value === null || value === undefined) return '';

	return String(value).trim();
}

export async function loadFootRiskSummary(): Promise<FootRiskRow[]> {
	const response = await fetch(FOOT_RISK_CSV_URL, {
		cache: 'no-store'
	});

	if (!response.ok) {
		throw new Error(`โหลดข้อมูล foot_risk_summary.csv ไม่สำเร็จ: ${response.status}`);
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
		console.warn('Foot risk CSV parse errors:', parsed.errors);
	}

	return parsed.data
		.map((row) => ({
			period_type: cleanText(row.period_type),
			fiscal_year_be: toNumber(row.fiscal_year_be),
			period_order: toNumber(row.period_order),
			period_label: cleanText(row.period_label),
			risk_code: cleanText(row.risk_code),
			risk_name: cleanText(row.risk_name),
			risk_order: toNumber(row.risk_order),
			total_hn: toNumber(row.total_hn)
		}))
		.filter((row) => row.fiscal_year_be > 0 && row.risk_code !== '');
}
