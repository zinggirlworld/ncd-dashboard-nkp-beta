<script lang="ts">
	import { base } from '$app/paths';
	import { onMount } from 'svelte';
	import { loadNcdIndicators, type NcdIndicator } from '$lib/data';
	import { loadFootRiskSummary, type FootRiskRow } from '$lib/footRiskData';
	import { indicatorMaster } from '$lib/indicatorMaster';

	import MonthlyTrendChart from '$lib/components/MonthlyTrendChart.svelte';
	import ActualTargetChart from '$lib/components/ActualTargetChart.svelte';
	import GapChart from '$lib/components/GapChart.svelte';
	import StatusDonutChart from '$lib/components/StatusDonutChart.svelte';
	import FootRiskChart from '$lib/components/FootRiskChart.svelte';

	import {
		Activity,
		AlertTriangle,
		BarChart3,
		CheckCircle2,
		ChevronDown,
		ClipboardList,
		Footprints,
		LineChart,
		Target,
		TrendingUp,
		UsersRound,
		XCircle
	} from 'lucide-svelte';

	type DetailRow = {
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
		category: string;
		hasData: boolean;
		displayStatus: string;
	};

	const screeningIndicatorNos = [13, 14, 15];

	let rows = $state<NcdIndicator[]>([]);
	let footRiskRows = $state<FootRiskRow[]>([]);

	let loading = $state(true);
	let errorMessage = $state('');
	let footRiskError = $state('');

	let selectedYear = $state(2569);
	let selectedPeriodType = $state('เดือน');
	let selectedPeriodOrder = $state<number | null>(null);
	let showDetailTable = $state(false);

	let years = $derived(
		[...new Set(rows.map((r) => r.fiscal_year_be))].filter((year) => year > 0).sort((a, b) => b - a)
	);

	let periodTypes = $derived(
		[...new Set(rows.map((r) => r.period_type))].filter(Boolean).sort((a, b) => {
			const order: Record<string, number> = {
				ปีงบประมาณ: 1,
				ไตรมาส: 2,
				เดือน: 3
			};

			return (order[a] ?? 99) - (order[b] ?? 99);
		})
	);

	let filteredRows = $derived(
		rows
			.filter((r) => r.fiscal_year_be === selectedYear)
			.filter((r) => r.period_type === selectedPeriodType)
			.sort((a, b) => {
				if (a.period_order !== b.period_order) return a.period_order - b.period_order;
				return a.indicator_no - b.indicator_no;
			})
	);

	let availablePeriods = $derived(
		[
			...new Map(
				filteredRows.map((r) => [
					r.period_order,
					{
						order: r.period_order,
						label: r.period_label
					}
				])
			).values()
		].sort((a, b) => a.order - b.order)
	);

	let latestPeriodOrder = $derived(
		filteredRows.length > 0 ? Math.max(...filteredRows.map((r) => r.period_order)) : 0
	);

	let activePeriodOrder = $derived(
		selectedPeriodOrder !== null &&
			availablePeriods.some((period) => period.order === selectedPeriodOrder)
			? selectedPeriodOrder
			: latestPeriodOrder
	);

	let currentRows = $derived(
		selectedPeriodType === 'เดือน' || selectedPeriodType === 'ไตรมาส'
			? filteredRows.filter((r) => r.period_order === activePeriodOrder)
			: filteredRows
	);

	let screeningRows = $derived(
		currentRows.filter((row) => screeningIndicatorNos.includes(row.indicator_no))
	);

	let currentFootRiskRows = $derived(
		footRiskRows
			.filter((row) => row.fiscal_year_be === selectedYear)
			.filter((row) => row.period_type === selectedPeriodType)
			.filter((row) =>
				selectedPeriodType === 'เดือน' || selectedPeriodType === 'ไตรมาส'
					? row.period_order === activePeriodOrder
					: true
			)
			.sort((a, b) => a.risk_order - b.risk_order)
	);

	let totalIndicators = $derived(currentRows.length);
	let passedCount = $derived(currentRows.filter((r) => r.status === 'ผ่าน').length);
	let failedCount = $derived(currentRows.filter((r) => r.status === 'ไม่ผ่าน').length);

	let screeningPassedCount = $derived(screeningRows.filter((r) => r.status === 'ผ่าน').length);
	let screeningFailedCount = $derived(screeningRows.filter((r) => r.status === 'ไม่ผ่าน').length);

	let clinicPatientTotal = $derived(
		currentRows.find((row) => row.indicator_no === 1)?.denominator ??
			Math.max(...currentRows.map((row) => row.denominator ?? 0), 0)
	);

	let eyeScreeningRow = $derived(currentRows.find((row) => row.indicator_no === 13));
	let oralScreeningRow = $derived(currentRows.find((row) => row.indicator_no === 14));
	let footScreeningRow = $derived(currentRows.find((row) => row.indicator_no === 15));

	let eyeScreeningCount = $derived(eyeScreeningRow?.numerator ?? 0);
	let oralScreeningCount = $derived(oralScreeningRow?.numerator ?? 0);
	let footScreeningCount = $derived(footScreeningRow?.numerator ?? 0);

	let eyeScreeningPercent = $derived(eyeScreeningRow?.actual_percent ?? 0);
	let oralScreeningPercent = $derived(oralScreeningRow?.actual_percent ?? 0);
	let footScreeningPercent = $derived(footScreeningRow?.actual_percent ?? 0);

	let averagePercent = $derived(
		currentRows.length > 0
			? currentRows.reduce((sum, r) => sum + (r.actual_percent ?? 0), 0) / currentRows.length
			: 0
	);

	let passRate = $derived(totalIndicators > 0 ? (passedCount * 100) / totalIndicators : 0);

	let currentPeriodLabel = $derived(currentRows[0]?.period_label ?? selectedPeriodType);

	let urgentRows = $derived(
		[...currentRows]
			.filter((row) => screeningIndicatorNos.includes(row.indicator_no))
			.filter((row) => row.status === 'ไม่ผ่าน')
			.sort((a, b) => (a.gap_from_target ?? 0) - (b.gap_from_target ?? 0))
			.slice(0, 3)
	);

	let detailRows = $derived<DetailRow[]>(
		indicatorMaster.map((master) => {
			const found = currentRows.find((row) => row.indicator_no === master.indicator_no);

			if (found) {
				return {
					period_type: found.period_type,
					fiscal_year_be: found.fiscal_year_be,
					period_order: found.period_order,
					period_label: found.period_label,
					indicator_no: found.indicator_no,
					indicator_name: found.indicator_name,
					target_text: found.target_text,
					target_type: found.target_type,
					target_value: found.target_value,
					numerator: found.numerator,
					denominator: found.denominator,
					actual_percent: found.actual_percent,
					status: found.status,
					gap_from_target: found.gap_from_target,
					category: master.category,
					hasData: true,
					displayStatus: found.status
				};
			}

			return {
				period_type: selectedPeriodType,
				fiscal_year_be: selectedYear,
				period_order: activePeriodOrder,
				period_label: currentPeriodLabel,
				indicator_no: master.indicator_no,
				indicator_name: master.indicator_name,
				target_text: master.target_text,
				target_type: master.target_type,
				target_value: master.target_value,
				numerator: null,
				denominator: null,
				actual_percent: null,
				status: 'รอข้อมูล',
				gap_from_target: null,
				category: master.category,
				hasData: false,
				displayStatus: 'รอข้อมูล'
			};
		})
	);

	let waitingCount = $derived(detailRows.filter((row) => !row.hasData).length);

	function formatNumber(value: number | null | undefined): string {
		if (value === null || value === undefined) return '-';

		return value.toLocaleString('th-TH', {
			maximumFractionDigits: 2
		});
	}

	function formatPercent(value: number | null | undefined): string {
		if (value === null || value === undefined) return '-';

		return `${value.toLocaleString('th-TH', {
			minimumFractionDigits: 2,
			maximumFractionDigits: 2
		})}%`;
	}

	function getStatusClass(status: string): string {
		if (status === 'ผ่าน') {
			return 'bg-emerald-100 text-emerald-700 ring-1 ring-emerald-200';
		}

		if (status === 'ไม่ผ่าน') {
			return 'bg-rose-100 text-rose-700 ring-1 ring-rose-200';
		}

		if (status === 'รอข้อมูล') {
			return 'bg-slate-100 text-slate-500 ring-1 ring-slate-200';
		}

		return 'bg-slate-100 text-slate-600 ring-1 ring-slate-200';
	}

	function getCategoryClass(category: string): string {
		if (category === 'ควบคุมน้ำตาล') return 'bg-sky-50 text-sky-700 ring-1 ring-sky-100';

		if (category === 'ภาวะแทรกซ้อนเฉียบพลัน') {
			return 'bg-rose-50 text-rose-700 ring-1 ring-rose-100';
		}

		if (category === 'Lipid / BP / ยา') {
			return 'bg-violet-50 text-violet-700 ring-1 ring-violet-100';
		}

		if (category === 'ไต') {
			return 'bg-indigo-50 text-indigo-700 ring-1 ring-indigo-100';
		}

		if (category === 'ตา / ฟัน / เท้า') {
			return 'bg-emerald-50 text-emerald-700 ring-1 ring-emerald-100';
		}

		if (category === 'ภาวะแทรกซ้อนเรื้อรัง') {
			return 'bg-amber-50 text-amber-700 ring-1 ring-amber-100';
		}

		return 'bg-slate-100 text-slate-600 ring-1 ring-slate-200';
	}

	function getShortIndicatorName(row: NcdIndicator): string {
		if (row.indicator_no === 1) return 'ตรวจ HbA1c';
		if (row.indicator_no === 2) return 'HbA1c < 7';
		if (row.indicator_no === 13) return 'ตรวจจอประสาทตา';
		if (row.indicator_no === 14) return 'ตรวจสุขภาพช่องปาก';
		if (row.indicator_no === 15) return 'ตรวจเท้า';

		return `ตัวชี้วัดที่ ${row.indicator_no}`;
	}

	function handlePeriodOrderChange(event: Event) {
		const select = event.currentTarget as HTMLSelectElement;
		selectedPeriodOrder = Number(select.value);
	}

	onMount(async () => {
		try {
			rows = await loadNcdIndicators();

			const availableYears = [...new Set(rows.map((r) => r.fiscal_year_be))]
				.filter((year) => year > 0)
				.sort((a, b) => b - a);

			if (availableYears.length > 0) {
				selectedYear = availableYears[0];
			}

			try {
				footRiskRows = await loadFootRiskSummary();
			} catch (error) {
				console.warn('โหลดข้อมูลความเสี่ยงเท้าไม่สำเร็จ:', error);
				footRiskError =
					error instanceof Error ? error.message : 'โหลดข้อมูลความเสี่ยงเท้าไม่สำเร็จ';
			}
		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'โหลดข้อมูล CSV ไม่สำเร็จ';
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>สรุปข้อมูลการตรวจคัดกรองภาวะแทรกซ้อนจากโรคเบาหวาน</title>
</svelte:head>

<div class="min-h-screen bg-[#EAF7F2] px-4 py-5 text-slate-800 md:px-8">
	<div class="mx-auto max-w-7xl space-y-5">
		<header
			class="overflow-hidden rounded-[1.75rem] border border-emerald-200 bg-gradient-to-r from-[#B9F4D8] via-[#C9F7E8] to-[#DDFBF1] p-5 shadow-[0_18px_50px_rgba(16,185,129,0.12)]"
		>
			<div class="flex flex-col gap-5 xl:flex-row xl:items-center xl:justify-between">
				<div class="max-w-4xl">
					<div class="flex items-center gap-4">
						<div
							class="grid h-16 w-16 place-items-center rounded-2xl bg-white/90 p-2 shadow-sm ring-1 ring-emerald-200"
						>
							<img
								src={`${base}/nkplogo.png`}
								alt="โรงพยาบาลนครพิงค์"
								class="h-full w-full object-contain"
							/>
						</div>

						<div>
							<p class="text-sm font-black text-emerald-800">โรงพยาบาลนครพิงค์</p>
							<p class="text-xs font-bold text-emerald-700">NCD Screening Dashboard</p>
						</div>
					</div>

					<h1 class="mt-4 text-2xl leading-tight font-black text-[#063F33] md:text-3xl">
						สรุปข้อมูลการให้บริการตรวจคัดกรองภาวะแทรกซ้อนจากโรคเบาหวาน
					</h1>

					<p class="mt-2 text-sm font-semibold text-emerald-800 md:text-base">
						คลินิกเบาหวาน โรงพยาบาลนครพิงค์ | สรุปผลตามปีงบประมาณ สำหรับคณะกรรมการตรวจติดตาม
					</p>
				</div>

				<div class="grid min-w-[320px] grid-cols-1 gap-3 sm:grid-cols-3">
					<label class="text-sm font-black text-emerald-900">
						ปีงบประมาณ
						<select
							class="mt-1 w-full rounded-2xl border border-emerald-300 bg-white px-4 py-3 font-bold text-emerald-900 shadow-sm transition outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100"
							bind:value={selectedYear}
							onchange={() => {
								selectedPeriodOrder = null;
							}}
						>
							{#each years as year}
								<option value={year}>{year}</option>
							{/each}
						</select>
					</label>

					<label class="text-sm font-black text-emerald-900">
						ช่วงเวลา
						<select
							class="mt-1 w-full rounded-2xl border border-emerald-300 bg-white px-4 py-3 font-bold text-emerald-900 shadow-sm transition outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100"
							bind:value={selectedPeriodType}
							onchange={() => {
								selectedPeriodOrder = null;
							}}
						>
							{#each periodTypes as periodType}
								<option value={periodType}>{periodType}</option>
							{/each}
						</select>
					</label>

					{#if selectedPeriodType !== 'ปีงบประมาณ'}
						<label class="text-sm font-black text-emerald-900">
							งวดข้อมูล
							<select
								class="mt-1 w-full rounded-2xl border border-emerald-300 bg-white px-4 py-3 font-bold text-emerald-900 shadow-sm transition outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100"
								value={activePeriodOrder}
								onchange={handlePeriodOrderChange}
							>
								{#each availablePeriods as period}
									<option value={period.order}>{period.label}</option>
								{/each}
							</select>
						</label>
					{/if}
				</div>
			</div>
		</header>

		{#if loading}
			<section class="rounded-3xl border border-emerald-100 bg-white p-6 shadow-sm">
				<p class="font-bold text-emerald-700">กำลังโหลดข้อมูล...</p>
			</section>
		{:else if errorMessage}
			<section class="rounded-3xl border border-rose-100 bg-rose-50 p-6 shadow-sm">
				<p class="font-bold text-rose-700">{errorMessage}</p>
				<p class="mt-2 text-sm text-rose-600">
					กรุณาตรวจสอบ CSV URL ในไฟล์ src/lib/data.ts หรือทดสอบเปิดลิงก์ CSV ใน Browser
				</p>
			</section>
		{:else if totalIndicators === 0}
			<section class="rounded-3xl border border-amber-100 bg-amber-50 p-6 shadow-sm">
				<p class="font-bold text-amber-700">ไม่พบข้อมูลในช่วงเวลาที่เลือก</p>
				<p class="mt-2 text-sm font-semibold text-amber-700">
					กรุณาเลือกปีงบประมาณ ช่วงเวลา หรืองวดข้อมูลใหม่
				</p>
			</section>
		{:else}
			<section class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-5">
				<div
					class="rounded-[1.5rem] border border-emerald-100 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
				>
					<div class="flex items-center justify-between">
						<p class="text-sm font-black text-slate-500">ตัวชี้วัดที่มีข้อมูล</p>
						<div
							class="grid h-11 w-11 place-items-center rounded-2xl bg-emerald-50 text-emerald-700"
						>
							<ClipboardList size={22} strokeWidth={2.5} />
						</div>
					</div>

					<p class="mt-3 text-5xl font-black text-emerald-700">
						{totalIndicators}
						<span class="text-2xl text-slate-400">/18</span>
					</p>
					<p class="mt-2 text-sm font-semibold text-slate-500">
						{currentPeriodLabel} | ปีงบประมาณ {selectedYear}
					</p>
				</div>

				<div
					class="rounded-[1.5rem] border border-sky-100 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
				>
					<div class="flex items-center justify-between">
						<p class="text-sm font-black text-slate-500">ผู้ป่วยเข้าคลินิก</p>
						<div class="grid h-11 w-11 place-items-center rounded-2xl bg-sky-50 text-sky-700">
							<UsersRound size={22} strokeWidth={2.5} />
						</div>
					</div>

					<p class="mt-3 text-5xl font-black text-sky-700">
						{formatNumber(clinicPatientTotal)}
					</p>

					<p class="mt-2 text-sm font-semibold text-slate-500">
						HN ไม่ซ้ำ | {currentPeriodLabel} ปีงบประมาณ {selectedYear}
					</p>
				</div>

				<div
					class="rounded-[1.5rem] border border-emerald-100 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
				>
					<div class="flex items-center justify-between">
						<p class="text-sm font-black text-slate-500">ผ่านเป้าหมายภาพรวม</p>
						<div
							class="grid h-11 w-11 place-items-center rounded-2xl bg-emerald-50 text-emerald-700"
						>
							<CheckCircle2 size={22} strokeWidth={2.5} />
						</div>
					</div>

					<p class="mt-3 text-5xl font-black text-emerald-600">{passedCount}</p>
					<p class="mt-2 text-sm font-semibold text-emerald-700">รวมทุกตัวชี้วัดที่มีข้อมูล</p>
				</div>

				<div
					class="rounded-[1.5rem] border border-rose-100 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
				>
					<div class="flex items-center justify-between">
						<p class="text-sm font-black text-slate-500">ไม่ผ่านเป้าหมายภาพรวม</p>
						<div class="grid h-11 w-11 place-items-center rounded-2xl bg-rose-50 text-rose-600">
							<XCircle size={22} strokeWidth={2.5} />
						</div>
					</div>

					<p class="mt-3 text-5xl font-black text-rose-500">{failedCount}</p>
					<p class="mt-2 text-sm font-semibold text-rose-600">รวมทุกตัวชี้วัดที่มีข้อมูล</p>
				</div>

				<div
					class="rounded-[1.5rem] border border-teal-100 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
				>
					<div class="flex items-center justify-between">
						<p class="text-sm font-black text-slate-500">ผลงานเฉลี่ยภาพรวม</p>
						<div class="grid h-11 w-11 place-items-center rounded-2xl bg-teal-50 text-teal-700">
							<Activity size={22} strokeWidth={2.5} />
						</div>
					</div>

					<p class="mt-3 text-5xl font-black text-teal-600">{formatPercent(averagePercent)}</p>
					<p class="mt-2 text-sm font-semibold text-slate-500">รวมทุกตัวชี้วัดที่มีข้อมูล</p>
				</div>
			</section>

			<section class="rounded-[1.75rem] border border-emerald-100 bg-white p-5 shadow-sm">
				<div class="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
					<div>
						<h2 class="text-2xl font-black text-[#063F33]">
							จำนวนผู้ป่วยที่ได้รับการตรวจคัดกรองแต่ละรายการ
						</h2>

						<p class="mt-1 text-sm font-medium text-slate-500">
							แสดงจำนวนผู้ป่วยที่ได้รับการตรวจตา ตรวจช่องปาก และตรวจเท้า
							จากฐานผู้ป่วยเข้าคลินิกทั้งหมด
						</p>

						<p class="mt-2 text-sm font-black text-amber-700">
							แต่ละรายการเทียบกับฐานผู้ป่วยเข้าคลินิก ไม่ใช่ตัวเลขที่นำมาบวกกัน
						</p>
					</div>

					<div class="rounded-2xl bg-sky-50 px-4 py-3 text-right ring-1 ring-sky-100">
						<p class="text-xs font-black text-sky-700">ฐานผู้ป่วยเข้าคลินิก</p>
						<p class="mt-1 text-2xl font-black text-sky-800">
							{formatNumber(clinicPatientTotal)} คน
						</p>
						<p class="text-xs font-semibold text-slate-500">
							{currentPeriodLabel} | ปีงบประมาณ {selectedYear}
						</p>
					</div>
				</div>

				<div class="mt-5 grid grid-cols-1 gap-4 md:grid-cols-3">
					<div class="rounded-3xl border border-emerald-100 bg-emerald-50/60 p-5">
						<p class="text-sm font-black text-emerald-700">ได้รับการตรวจจอประสาทตา</p>

						<div class="mt-3 flex items-end gap-2">
							<p class="text-4xl font-black text-emerald-800">
								{formatNumber(eyeScreeningCount)}
							</p>
							<p class="pb-1 text-lg font-black text-emerald-600">
								/ {formatNumber(clinicPatientTotal)} คน
							</p>
						</div>

						<p class="mt-2 text-sm font-semibold text-slate-500">
							คิดเป็น {formatPercent(eyeScreeningPercent)} ของผู้ป่วยเข้าคลินิก
						</p>

						<div class="mt-4 h-3 overflow-hidden rounded-full bg-white">
							<div
								class="h-full rounded-full bg-emerald-500"
								style={`width: ${Math.min(eyeScreeningPercent, 100)}%`}
							></div>
						</div>
					</div>

					<div class="rounded-3xl border border-amber-100 bg-amber-50/70 p-5">
						<p class="text-sm font-black text-amber-700">ได้รับการตรวจช่องปาก / ฟัน</p>

						<div class="mt-3 flex items-end gap-2">
							<p class="text-4xl font-black text-amber-800">
								{formatNumber(oralScreeningCount)}
							</p>
							<p class="pb-1 text-lg font-black text-amber-600">
								/ {formatNumber(clinicPatientTotal)} คน
							</p>
						</div>

						<p class="mt-2 text-sm font-semibold text-slate-500">
							คิดเป็น {formatPercent(oralScreeningPercent)} ของผู้ป่วยเข้าคลินิก
						</p>

						<div class="mt-4 h-3 overflow-hidden rounded-full bg-white">
							<div
								class="h-full rounded-full bg-amber-500"
								style={`width: ${Math.min(oralScreeningPercent, 100)}%`}
							></div>
						</div>
					</div>

					<div class="rounded-3xl border border-violet-100 bg-violet-50/70 p-5">
						<p class="text-sm font-black text-violet-700">ได้รับการตรวจเท้าอย่างละเอียด</p>

						<div class="mt-3 flex items-end gap-2">
							<p class="text-4xl font-black text-violet-800">
								{formatNumber(footScreeningCount)}
							</p>
							<p class="pb-1 text-lg font-black text-violet-600">
								/ {formatNumber(clinicPatientTotal)} คน
							</p>
						</div>

						<p class="mt-2 text-sm font-semibold text-slate-500">
							คิดเป็น {formatPercent(footScreeningPercent)} ของผู้ป่วยเข้าคลินิก
						</p>

						<div class="mt-4 h-3 overflow-hidden rounded-full bg-white">
							<div
								class="h-full rounded-full bg-violet-500"
								style={`width: ${Math.min(footScreeningPercent, 100)}%`}
							></div>
						</div>
					</div>
				</div>

				<div class="mt-5 rounded-3xl border border-slate-100 bg-slate-50 px-5 py-4">
					<p class="text-sm font-bold text-slate-700">
						อ่านอย่างไร:
						<span class="font-medium text-slate-600">
							ตัวเลขแต่ละรายการเป็นจำนวนผู้ป่วยที่ได้รับการตรวจจากฐานผู้ป่วยเข้าคลินิกทั้งหมด
							ไม่ใช่ตัวเลขที่ต้องนำมาบวกกัน เพราะผู้ป่วย 1 คนอาจได้รับการตรวจมากกว่า 1 รายการ
							หรืออาจยังไม่ได้รับการตรวจบางรายการ
						</span>
					</p>
				</div>
			</section>

			<section
				class="rounded-[1.75rem] border border-amber-100 bg-gradient-to-r from-amber-50 via-white to-white p-5 shadow-sm"
			>
				<div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
					<div class="flex items-center gap-3">
						<div class="grid h-11 w-11 place-items-center rounded-2xl bg-amber-100 text-amber-700">
							<AlertTriangle size={23} strokeWidth={2.5} />
						</div>

						<div>
							<p class="text-sm font-black text-amber-700">เฉพาะตรวจตา ตรวจช่องปาก และตรวจเท้า</p>
							<h2 class="mt-1 text-2xl font-black text-[#063F33]">
								ประเด็นคัดกรองที่ควรเร่งติดตาม
							</h2>
						</div>
					</div>

					<div
						class="rounded-full bg-white px-4 py-2 text-sm font-bold text-amber-700 ring-1 ring-amber-100"
					>
						{currentPeriodLabel} | ปีงบประมาณ {selectedYear}
					</div>
				</div>

				<p class="mt-3 text-sm font-medium text-slate-500">
					เรียงจากช่องว่างจากเป้าหมายมากที่สุด เพื่อช่วยให้เห็นรายการคัดกรองที่ควรติดตามก่อน
				</p>

				{#if urgentRows.length > 0}
					<div class="mt-5 grid grid-cols-1 gap-4 md:grid-cols-3">
						{#each urgentRows as row, index}
							<div class="rounded-3xl border border-rose-100 bg-white p-5 shadow-sm">
								<div class="flex items-start justify-between gap-3">
									<div>
										<p class="text-xs font-black text-rose-500">ลำดับที่ {index + 1}</p>
										<h3 class="mt-1 text-lg font-black text-slate-800">
											{getShortIndicatorName(row)}
										</h3>
									</div>

									<span class="rounded-full bg-rose-100 px-3 py-1 text-xs font-black text-rose-700">
										{row.status}
									</span>
								</div>

								<div class="mt-5 grid grid-cols-2 gap-3">
									<div class="rounded-2xl bg-slate-50 p-3">
										<p class="text-xs font-bold text-slate-400">ผลงาน</p>
										<p class="mt-1 text-2xl font-black text-slate-800">
											{formatPercent(row.actual_percent)}
										</p>
									</div>

									<div class="rounded-2xl bg-slate-50 p-3">
										<p class="text-xs font-bold text-slate-400">เป้าหมาย</p>
										<p class="mt-1 text-2xl font-black text-slate-800">
											{row.target_text}
										</p>
									</div>
								</div>

								<div class="mt-4 rounded-2xl bg-rose-50 p-3">
									<p class="text-xs font-bold text-rose-500">Gap จากเป้าหมาย</p>
									<p class="mt-1 text-3xl font-black text-rose-600">
										{formatNumber(row.gap_from_target)}
									</p>
								</div>
							</div>
						{/each}
					</div>
				{:else}
					<div class="mt-5 rounded-3xl border border-emerald-100 bg-emerald-50 p-5">
						<p class="font-bold text-emerald-700">
							ตัวชี้วัดคัดกรองตา ช่องปาก และเท้า ในช่วงเวลานี้ผ่านเป้าหมายทั้งหมด
						</p>
					</div>
				{/if}
			</section>

			<section class="rounded-[1.75rem] border border-emerald-100 bg-white p-5 shadow-sm">
				<div class="mb-4 flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
					<div class="flex items-center gap-3">
						<div
							class="grid h-11 w-11 place-items-center rounded-2xl bg-emerald-50 text-emerald-700"
						>
							<LineChart size={23} strokeWidth={2.5} />
						</div>

						<div>
							<h2 class="text-2xl font-black text-[#063F33]">แนวโน้มผลงานรายเดือน</h2>
							<p class="mt-1 text-sm font-medium text-slate-500">
								แสดงแนวโน้มร้อยละของการตรวจตา ตรวจช่องปาก และตรวจเท้า
							</p>
						</div>
					</div>

					<p class="rounded-full bg-emerald-50 px-4 py-2 text-sm font-bold text-emerald-700">
						ปีงบประมาณ {selectedYear}
					</p>
				</div>

				<MonthlyTrendChart {rows} {selectedYear} />
			</section>

			<section class="grid grid-cols-1 gap-5 xl:grid-cols-[1.45fr_0.85fr]">
				<div class="rounded-[1.75rem] border border-emerald-100 bg-white p-5 shadow-sm">
					<div class="mb-6 flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
						<div class="flex items-center gap-3">
							<div class="grid h-11 w-11 place-items-center rounded-2xl bg-teal-50 text-teal-700">
								<Target size={23} strokeWidth={2.5} />
							</div>

							<div>
								<h2 class="text-2xl font-black text-[#063F33]">ผลงานเทียบเป้าหมาย</h2>
								<p class="mt-1 text-sm font-medium text-slate-500">
									แสดงเฉพาะตัวชี้วัดกลุ่มคัดกรองภาวะแทรกซ้อน ตา ช่องปาก และเท้า
								</p>
							</div>
						</div>

						<div class="rounded-full bg-emerald-50 px-4 py-2 text-sm font-bold text-emerald-700">
							{currentPeriodLabel} | ปีงบประมาณ {selectedYear}
						</div>
					</div>

					<ActualTargetChart rows={currentRows} />
				</div>

				<div class="space-y-5">
					<section class="rounded-[1.75rem] border border-emerald-100 bg-white p-5 shadow-sm">
						<div class="flex items-center gap-3">
							<div
								class="grid h-10 w-10 place-items-center rounded-2xl bg-emerald-50 text-emerald-700"
							>
								<BarChart3 size={21} strokeWidth={2.5} />
							</div>

							<div>
								<h2 class="text-xl font-black text-[#063F33]">สถานะคัดกรอง</h2>
								<p class="mt-1 text-sm font-medium text-slate-500">
									ผ่าน / ไม่ผ่าน เฉพาะตรวจตา ช่องปาก และเท้า
								</p>
							</div>
						</div>

						<div class="mt-4">
							<StatusDonutChart rows={screeningRows} />
						</div>

						<div class="mt-4 grid grid-cols-2 gap-3">
							<div class="rounded-2xl bg-emerald-50 p-4">
								<p class="text-sm font-bold text-emerald-700">ผ่าน</p>
								<p class="mt-1 text-3xl font-black text-emerald-700">
									{screeningPassedCount}
								</p>
							</div>

							<div class="rounded-2xl bg-rose-50 p-4">
								<p class="text-sm font-bold text-rose-700">ไม่ผ่าน</p>
								<p class="mt-1 text-3xl font-black text-rose-700">
									{screeningFailedCount}
								</p>
							</div>
						</div>
					</section>

					<section class="rounded-[1.75rem] border border-emerald-100 bg-white p-5 shadow-sm">
						<div class="flex items-center gap-3">
							<div class="grid h-10 w-10 place-items-center rounded-2xl bg-rose-50 text-rose-600">
								<TrendingUp size={21} strokeWidth={2.5} />
							</div>

							<div>
								<h2 class="text-xl font-black text-[#063F33]">Gap จากเป้าหมาย</h2>
								<p class="mt-1 text-sm font-medium text-slate-500">
									แสดงเฉพาะรายการคัดกรองที่ต่ำกว่าเป้าหมาย
								</p>
							</div>
						</div>

						<div class="mt-5">
							<GapChart rows={currentRows} />
						</div>
					</section>
				</div>
			</section>

			<section class="rounded-[1.75rem] border border-amber-100 bg-white p-5 shadow-sm">
				<div class="mb-5 flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
					<div class="flex items-center gap-3">
						<div class="grid h-11 w-11 place-items-center rounded-2xl bg-amber-50 text-amber-700">
							<Footprints size={23} strokeWidth={2.5} />
						</div>

						<div>
							<h2 class="text-2xl font-black text-[#063F33]">ผลการประเมินความเสี่ยงเท้า</h2>
							<p class="mt-1 text-sm font-medium text-slate-500">
								แสดงจำนวน HN แยกตามระดับความเสี่ยงจากการตรวจเท้า
							</p>
						</div>
					</div>

					<div class="rounded-full bg-amber-50 px-4 py-2 text-sm font-bold text-amber-700">
						{currentPeriodLabel} | ปีงบประมาณ {selectedYear}
					</div>
				</div>

				{#if footRiskError}
					<div class="rounded-3xl border border-amber-100 bg-amber-50 p-5">
						<p class="font-bold text-amber-700">{footRiskError}</p>
						<p class="mt-1 text-sm font-semibold text-slate-500">
							กรุณาตรวจสอบว่าไฟล์ foot_risk_summary.csv อยู่ในโฟลเดอร์ static และเปิดผ่าน
							/foot_risk_summary.csv ได้
						</p>
					</div>
				{:else}
					<FootRiskChart rows={currentFootRiskRows} />
				{/if}
			</section>

			<section class="rounded-[1.75rem] border border-emerald-100 bg-white p-5 shadow-sm">
				<div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
					<div class="flex items-center gap-3">
						<div class="grid h-11 w-11 place-items-center rounded-2xl bg-slate-50 text-slate-600">
							<ClipboardList size={23} strokeWidth={2.5} />
						</div>

						<div>
							<h2 class="text-2xl font-black text-[#063F33]">รายละเอียดตัวชี้วัด</h2>
							<p class="mt-1 text-sm font-medium text-slate-500">
								แสดงกรอบตัวชี้วัด NCD ครบ 18 รายการ โดยรายการที่ยังไม่เชื่อมข้อมูลจะแสดงเป็น
								“รอข้อมูล”
							</p>
						</div>
					</div>

					<div class="flex flex-col gap-3 sm:flex-row sm:items-center">
						<div class="flex flex-wrap gap-2">
							<span
								class="rounded-full bg-emerald-50 px-4 py-2 text-sm font-black text-emerald-700 ring-1 ring-emerald-100"
							>
								มีข้อมูล {totalIndicators}
							</span>

							<span
								class="rounded-full bg-slate-50 px-4 py-2 text-sm font-black text-slate-500 ring-1 ring-slate-100"
							>
								รอข้อมูล {waitingCount}
							</span>

							<span
								class="rounded-full bg-white px-4 py-2 text-sm font-black text-slate-600 ring-1 ring-slate-100"
							>
								ทั้งหมด {detailRows.length}
							</span>
						</div>

						<button
							type="button"
							class="inline-flex items-center gap-2 rounded-full bg-emerald-600 px-5 py-2 text-sm font-black text-white shadow-sm transition hover:bg-emerald-700"
							onclick={() => (showDetailTable = !showDetailTable)}
						>
							<ChevronDown
								size={17}
								strokeWidth={3}
								class={showDetailTable ? 'rotate-180 transition' : 'transition'}
							/>
							{showDetailTable ? 'ซ่อนรายละเอียด' : 'แสดงรายละเอียด'}
						</button>
					</div>
				</div>

				{#if showDetailTable}
					<div class="mt-5 overflow-x-auto">
						<table class="w-full border-collapse text-left text-sm">
							<thead>
								<tr class="border-b bg-emerald-50 text-emerald-900">
									<th class="px-4 py-3 whitespace-nowrap">ลำดับ</th>
									<th class="px-4 py-3 whitespace-nowrap">หมวด</th>
									<th class="min-w-[460px] px-4 py-3">ตัวชี้วัด</th>
									<th class="px-4 py-3 text-right whitespace-nowrap">เป้าหมาย</th>
									<th class="px-4 py-3 text-right whitespace-nowrap">ตัวตั้ง</th>
									<th class="px-4 py-3 text-right whitespace-nowrap">ตัวหาร</th>
									<th class="px-4 py-3 text-right whitespace-nowrap">ผลงาน</th>
									<th class="px-4 py-3 text-right whitespace-nowrap">Gap</th>
									<th class="px-4 py-3 text-center whitespace-nowrap">สถานะ</th>
								</tr>
							</thead>

							<tbody>
								{#each detailRows as row}
									<tr
										class={`border-b ${
											row.hasData ? 'hover:bg-emerald-50/60' : 'bg-slate-50/70 text-slate-400'
										}`}
									>
										<td
											class={`px-4 py-3 font-black ${
												row.hasData ? 'text-emerald-700' : 'text-slate-400'
											}`}
										>
											{row.indicator_no}
										</td>

										<td class="px-4 py-3">
											<span
												class={`rounded-full px-3 py-1 text-xs font-black whitespace-nowrap ${getCategoryClass(
													row.category
												)}`}
											>
												{row.category}
											</span>
										</td>

										<td
											class={`px-4 py-3 font-medium ${
												row.hasData ? 'text-slate-700' : 'text-slate-400'
											}`}
										>
											{row.indicator_name}
										</td>

										<td class="px-4 py-3 text-right font-bold">{row.target_text}</td>
										<td class="px-4 py-3 text-right">{formatNumber(row.numerator)}</td>
										<td class="px-4 py-3 text-right">{formatNumber(row.denominator)}</td>

										<td
											class={`px-4 py-3 text-right font-black ${
												row.hasData ? 'text-emerald-700' : 'text-slate-400'
											}`}
										>
											{formatPercent(row.actual_percent)}
										</td>

										<td
											class={`px-4 py-3 text-right font-black ${
												!row.hasData
													? 'text-slate-400'
													: (row.gap_from_target ?? 0) >= 0
														? 'text-emerald-600'
														: 'text-rose-500'
											}`}
										>
											{formatNumber(row.gap_from_target)}
										</td>

										<td class="px-4 py-3 text-center">
											<span
												class={`rounded-full px-3 py-1 text-xs font-black ${getStatusClass(
													row.displayStatus
												)}`}
											>
												{row.displayStatus}
											</span>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{:else}
					<div class="mt-5 rounded-2xl bg-emerald-50 px-5 py-4">
						<p class="text-sm font-semibold text-emerald-800">
							แสดงเฉพาะกราฟและสรุปภาพรวมเพื่อให้อ่านง่าย หากต้องการดูกรอบตัวชี้วัด NCD ทั้ง 18 ข้อ
							ให้กดปุ่ม “แสดงรายละเอียด”
						</p>
					</div>
				{/if}
			</section>
		{/if}
	</div>
</div>
