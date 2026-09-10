import { base } from '$app/paths';
import Papa from 'papaparse';

export type PeriodType = 'ปีงบประมาณ' | 'ไตรมาส';

export type FootRiskRow = {
	period_type: PeriodType;
	fiscal_year_be: number;
	period_order: number;
	period_label: string;
	risk_code: 'Z0280' | 'Z0281' | 'Z0282' | 'Z0283';
	risk_name: string;
	risk_order: number;
	total_hn: number;
};

const FOOT_RISK_CSV_URL = `${base}/foot_risk_summary.csv`;
const ALLOWED_PERIOD_TYPES = new Set<PeriodType>(['ปีงบประมาณ', 'ไตรมาส']);
const RISK_DEFINITIONS = {
	Z0280: { order: 1, name: 'เสี่ยงต่ำ' },
	Z0281: { order: 2, name: 'เสี่ยงปานกลาง' },
	Z0282: { order: 3, name: 'เสี่ยงสูง' },
	Z0283: { order: 4, name: 'เสี่ยงสูงมาก' }
} as const;
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

function parseRequiredInteger(value: unknown, field: string, rowNumber: number): number {
	const raw = String(value ?? '')
		.replace(/,/g, '')
		.trim();
	const parsed = Number(raw);
	if (!raw || !Number.isInteger(parsed)) {
		throw new Error(`ข้อมูลแถว ${rowNumber}: ${field} ต้องเป็นจำนวนเต็ม`);
	}
	return parsed;
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

function validatePeriod(periodType: PeriodType, periodOrder: number, rowNumber: number): void {
	if (periodType === 'ปีงบประมาณ' && periodOrder !== 0) {
		throw new Error(`ข้อมูลแถว ${rowNumber}: ปีงบประมาณต้องมี period_order = 0`);
	}
	if (periodType === 'ไตรมาส' && (periodOrder < 1 || periodOrder > 4)) {
		throw new Error(`ข้อมูลแถว ${rowNumber}: ไตรมาสต้องมี period_order ระหว่าง 1-4`);
	}
}

function validateDataset(rows: FootRiskRow[]): void {
	const seenKeys = new Set<string>();
	const periodRiskCodes = new Map<string, Set<string>>();

	for (const row of rows) {
		const rowKey = `${row.period_type}|${row.fiscal_year_be}|${row.period_order}|${row.risk_code}`;
		if (seenKeys.has(rowKey)) {
			throw new Error(`พบข้อมูลซ้ำในไฟล์: ${rowKey}`);
		}
		seenKeys.add(rowKey);

		const periodKey = `${row.period_type}|${row.fiscal_year_be}|${row.period_order}`;
		const codes = periodRiskCodes.get(periodKey) ?? new Set<string>();
		codes.add(row.risk_code);
		periodRiskCodes.set(periodKey, codes);
	}

	for (const [periodKey, codes] of periodRiskCodes) {
		if (codes.size !== 4) {
			throw new Error(`งวดข้อมูล ${periodKey} มีระดับความเสี่ยงไม่ครบ 4 ระดับ`);
		}
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
		const firstError = parsed.errors[0];
		throw new Error(
			`ไฟล์ข้อมูลอ่านไม่สมบูรณ์${firstError?.row !== undefined ? ` แถว ${firstError.row + 2}` : ''}: ${firstError?.message ?? 'CSV parse error'}`
		);
	}

	const rows = parsed.data.map((rawRow, index): FootRiskRow => {
		const rowNumber = index + 2;
		const periodType = cleanText(rawRow.period_type) as PeriodType;
		if (!ALLOWED_PERIOD_TYPES.has(periodType)) {
			throw new Error(`ข้อมูลแถว ${rowNumber}: period_type ไม่ถูกต้อง`);
		}

		const fiscalYear = parseRequiredInteger(rawRow.fiscal_year_be, 'fiscal_year_be', rowNumber);
		const periodOrder = parseRequiredInteger(rawRow.period_order, 'period_order', rowNumber);
		const riskOrder = parseRequiredInteger(rawRow.risk_order, 'risk_order', rowNumber);
		const totalHn = parseRequiredInteger(rawRow.total_hn, 'total_hn', rowNumber);
		const riskCode = cleanText(rawRow.risk_code) as FootRiskRow['risk_code'];
		const riskName = cleanText(rawRow.risk_name);
		const periodLabel = cleanText(rawRow.period_label);

		if (fiscalYear <= 0) throw new Error(`ข้อมูลแถว ${rowNumber}: fiscal_year_be ไม่ถูกต้อง`);
		if (totalHn < 0) throw new Error(`ข้อมูลแถว ${rowNumber}: total_hn ต้องไม่ติดลบ`);
		if (!periodLabel) throw new Error(`ข้อมูลแถว ${rowNumber}: period_label ห้ามว่าง`);
		validatePeriod(periodType, periodOrder, rowNumber);

		const riskDefinition = RISK_DEFINITIONS[riskCode];
		if (!riskDefinition) throw new Error(`ข้อมูลแถว ${rowNumber}: risk_code ไม่ถูกต้อง`);
		if (riskOrder !== riskDefinition.order) {
			throw new Error(`ข้อมูลแถว ${rowNumber}: risk_order ไม่ตรงกับ ${riskCode}`);
		}
		if (riskName !== riskDefinition.name) {
			throw new Error(`ข้อมูลแถว ${rowNumber}: risk_name ไม่ตรงกับ ${riskCode}`);
		}

		return {
			period_type: periodType,
			fiscal_year_be: fiscalYear,
			period_order: periodOrder,
			period_label: periodLabel,
			risk_code: riskCode,
			risk_name: riskName,
			risk_order: riskOrder,
			total_hn: totalHn
		};
	});

	validateDataset(rows);
	return rows;
}
