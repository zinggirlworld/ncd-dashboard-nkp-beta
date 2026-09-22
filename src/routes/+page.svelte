<script lang="ts">
	import { base } from '$app/paths';
	import { onMount } from 'svelte';
	import { loadNcdIndicators, type NcdIndicator, type PeriodType } from '$lib/data';
	import { loadFootRiskSummary, type FootRiskRow } from '$lib/footRiskData';

	import ScreeningCoverageChart from '$lib/components/ScreeningCoverageChart.svelte';
	import ScreeningTrendChart from '$lib/components/ScreeningTrendChart.svelte';
	import FootRiskChart from '$lib/components/FootRiskChart.svelte';

	import { CalendarRange, Eye, Footprints, Smile, TrendingUp } from 'lucide-svelte';

	const SCREENING_NOS = [13, 14, 15] as const;

	let rows = $state<NcdIndicator[]>([]);
	let footRiskRows = $state<FootRiskRow[]>([]);

	let footRiskOpen = $state(false);
	let loading = $state(true);
	let errorMessage = $state('');
	let footRiskError = $state('');

	let selectedYear = $state(2569);
	let selectedPeriodType = $state<PeriodType>('ปีงบประมาณ');
	let selectedPeriodOrder = $state<number | null>(null);

	let years = $derived(
		[...new Set(rows.map((row) => row.fiscal_year_be))]
			.filter((year) => year > 0)
			.sort((a, b) => b - a)
	);

	const periodTypes: PeriodType[] = ['ปีงบประมาณ', 'ไตรมาส'];

	let filteredRows = $derived(
		rows
			.filter((row) => row.fiscal_year_be === selectedYear)
			.filter((row) => row.period_type === selectedPeriodType)
			.sort((a, b) => {
				if (a.period_order !== b.period_order) return a.period_order - b.period_order;
				return a.indicator_no - b.indicator_no;
			})
	);

	let availablePeriods = $derived.by(() => {
		const periods = [
			...new Map(
				filteredRows.map((row) => [
					row.period_order,
					{ order: row.period_order, label: row.period_label }
				])
			).values()
		].sort((a, b) => a.order - b.order);

		if (periods.length > 0) return periods;

		if (selectedPeriodType === 'ไตรมาส') {
			return [
				{ order: 1, label: 'ไตรมาส 1' },
				{ order: 2, label: 'ไตรมาส 2' },
				{ order: 3, label: 'ไตรมาส 3' },
				{ order: 4, label: 'ไตรมาส 4' }
			];
		}

		return [{ order: 0, label: `ปีงบประมาณ ${selectedYear}` }];
	});

	let latestPeriodOrder = $derived(
		filteredRows.length > 0
			? Math.max(...filteredRows.map((row) => row.period_order))
			: (availablePeriods[0]?.order ?? 0)
	);

	let activePeriodOrder = $derived(
		selectedPeriodOrder !== null &&
			availablePeriods.some((period) => period.order === selectedPeriodOrder)
			? selectedPeriodOrder
			: latestPeriodOrder
	);

	let currentRows = $derived(
		selectedPeriodType === 'ไตรมาส'
			? filteredRows.filter((row) => row.period_order === activePeriodOrder)
			: filteredRows
	);

	let screeningRows = $derived(
		currentRows
			.filter((row) => SCREENING_NOS.includes(row.indicator_no as (typeof SCREENING_NOS)[number]))
			.sort((a, b) => a.indicator_no - b.indicator_no)
	);

	let eyeRow = $derived(screeningRows.find((row) => row.indicator_no === 13));
	let oralRow = $derived(screeningRows.find((row) => row.indicator_no === 14));
	let footRow = $derived(screeningRows.find((row) => row.indicator_no === 15));

	let clinicPatientTotal = $derived(
		Math.max(...screeningRows.map((row) => row.denominator ?? 0), 0)
	);

	let eyeCount = $derived(eyeRow?.numerator ?? 0);
	let oralCount = $derived(oralRow?.numerator ?? 0);
	let footCount = $derived(footRow?.numerator ?? 0);

	let eyePercent = $derived(eyeRow?.actual_percent ?? 0);
	let oralPercent = $derived(oralRow?.actual_percent ?? 0);
	let footPercent = $derived(footRow?.actual_percent ?? 0);

	let eyePending = $derived(Math.max((eyeRow?.denominator ?? 0) - eyeCount, 0));
	let oralPending = $derived(Math.max((oralRow?.denominator ?? 0) - oralCount, 0));
	let footPending = $derived(Math.max((footRow?.denominator ?? 0) - footCount, 0));

	let hasScreeningData = $derived(screeningRows.some((row) => (row.denominator ?? 0) > 0));

	let currentPeriodLabel = $derived(
		screeningRows[0]?.period_label ??
			currentRows[0]?.period_label ??
			availablePeriods.find((period) => period.order === activePeriodOrder)?.label ??
			selectedPeriodType
	);

	let currentFootRiskRows = $derived(
		footRiskRows
			.filter((row) => row.fiscal_year_be === selectedYear)
			.filter((row) => row.period_type === selectedPeriodType)
			.filter((row) =>
				selectedPeriodType === 'ไตรมาส' ? row.period_order === activePeriodOrder : true
			)
			.sort((a, b) => a.risk_order - b.risk_order)
	);

	let footRiskTotal = $derived(
		currentFootRiskRows.reduce((sum, row) => sum + (row.total_hn ?? 0), 0)
	);

	let footHighRiskTotal = $derived(
		currentFootRiskRows
			.filter((row) => row.risk_code === 'Z0282' || row.risk_code === 'Z0283')
			.reduce((sum, row) => sum + (row.total_hn ?? 0), 0)
	);

	let footHighRiskPercent = $derived(
		footRiskTotal > 0 ? (footHighRiskTotal * 100) / footRiskTotal : 0
	);

	function formatNumber(value: number | null | undefined): string {
		if (value === null || value === undefined) return '-';
		return value.toLocaleString('th-TH', { maximumFractionDigits: 2 });
	}

	function formatPercent(value: number | null | undefined): string {
		if (value === null || value === undefined) return '-';
		return `${value.toLocaleString('th-TH', {
			minimumFractionDigits: 2,
			maximumFractionDigits: 2
		})}%`;
	}

	function handlePeriodOrderChange(event: Event) {
		selectedPeriodOrder = Number((event.currentTarget as HTMLSelectElement).value);
	}

	onMount(async () => {
		try {
			rows = await loadNcdIndicators();

			const availableYears = [...new Set(rows.map((row) => row.fiscal_year_be))]
				.filter((year) => year > 0)
				.sort((a, b) => b - a);

			if (availableYears.length > 0) selectedYear = availableYears[0];

			try {
				footRiskRows = await loadFootRiskSummary();
			} catch (error) {
				console.warn('โหลดข้อมูลความเสี่ยงเท้าไม่สำเร็จ:', error);
				footRiskError =
					error instanceof Error ? error.message : 'โหลดข้อมูลความเสี่ยงเท้าไม่สำเร็จ';
			}
		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'โหลดข้อมูลการคัดกรองไม่สำเร็จ';
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>Dashboard การคัดกรองภาวะแทรกซ้อนในผู้ป่วยเบาหวาน</title>
	<meta
		name="description"
		content="Dashboard สรุปข้อมูลการตรวจตา ตรวจสุขภาพช่องปาก และตรวจเท้าในผู้ป่วยเบาหวาน โรงพยาบาลนครพิงค์"
	/>
</svelte:head>

<main class="min-h-screen bg-[#EAF7F2] px-4 py-5 text-slate-800 md:px-8">
	<div class="mx-auto max-w-7xl space-y-5">
		<header
			class="overflow-hidden rounded-[1.75rem] border border-emerald-200 bg-gradient-to-r from-[#B9F4D8] via-[#C9F7E8] to-[#DDFBF1] p-5 shadow-[0_18px_50px_rgba(16,185,129,0.12)] md:p-6"
		>
			<div class="flex flex-col gap-5 xl:flex-row xl:items-center xl:justify-between">
				<div class="max-w-4xl">
					<div class="flex items-center gap-4">
						<div
							class="grid h-16 w-16 shrink-0 place-items-center rounded-2xl bg-white/90 p-2 shadow-sm ring-1 ring-emerald-200"
						>
							<img
								src={`${base}/nkplogo.png`}
								alt="โรงพยาบาลนครพิงค์"
								class="h-full w-full object-contain"
							/>
						</div>
						<div>
							<p class="text-sm font-black text-emerald-800">โรงพยาบาลนครพิงค์</p>
							<p class="text-xs font-bold text-emerald-700">Diabetes Complication Screening</p>
						</div>
					</div>

					<h1 class="mt-4 text-2xl leading-tight font-black text-[#063F33] md:text-3xl">
						ภาพรวมการคัดกรองภาวะแทรกซ้อนในผู้ป่วยเบาหวาน
					</h1>
					<p class="mt-2 text-sm font-semibold text-emerald-800 md:text-base">
						ตรวจจอประสาทตา · ตรวจสุขภาพช่องปากและฟัน · ตรวจเท้า
					</p>
				</div>

				<div
					class={`grid w-full gap-3 xl:max-w-2xl ${selectedPeriodType === 'ไตรมาส' ? 'sm:grid-cols-3' : 'sm:grid-cols-2'}`}
				>
					<label for="fiscal-year" class="text-sm font-black text-emerald-900">
						ปีงบประมาณ
						<select
							id="fiscal-year"
							class="mt-1 min-h-11 w-full rounded-2xl border border-emerald-300 bg-white px-4 py-3 font-bold text-emerald-900 shadow-sm transition outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100"
							bind:value={selectedYear}
							onchange={() => (selectedPeriodOrder = null)}
						>
							{#each years as year (year)}
								<option value={year}>{year}</option>
							{/each}
						</select>
					</label>

					<label for="period-type" class="text-sm font-black text-emerald-900">
						ช่วงเวลา
						<select
							id="period-type"
							class="mt-1 min-h-11 w-full rounded-2xl border border-emerald-300 bg-white px-4 py-3 font-bold text-emerald-900 shadow-sm transition outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100"
							bind:value={selectedPeriodType}
							onchange={() => (selectedPeriodOrder = null)}
						>
							{#each periodTypes as periodType (periodType)}
								<option value={periodType}>{periodType}</option>
							{/each}
						</select>
					</label>

					{#if selectedPeriodType === 'ไตรมาส'}
						<label for="period-order" class="text-sm font-black text-emerald-900">
							งวดข้อมูล
							<select
								id="period-order"
								class="mt-1 min-h-11 w-full rounded-2xl border border-emerald-300 bg-white px-4 py-3 font-bold text-emerald-900 shadow-sm transition outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-100"
								value={activePeriodOrder}
								onchange={handlePeriodOrderChange}
							>
								{#each availablePeriods as period (period.order)}
									<option value={period.order}>{period.label}</option>
								{/each}
							</select>
						</label>
					{/if}
				</div>
			</div>
		</header>

		{#if loading}
			<section
				aria-live="polite"
				class="rounded-3xl border border-emerald-100 bg-white p-6 shadow-sm"
			>
				<p class="font-bold text-emerald-700">กำลังโหลดข้อมูล...</p>
			</section>
		{:else if errorMessage}
			<section role="alert" class="rounded-3xl border border-rose-100 bg-rose-50 p-6 shadow-sm">
				<p class="font-bold text-rose-700">ไม่สามารถโหลดข้อมูลการคัดกรองได้</p>
				<p class="mt-2 text-sm font-semibold text-rose-600">{errorMessage}</p>
			</section>
		{:else if !hasScreeningData}
			<section class="rounded-3xl border border-amber-100 bg-amber-50 p-6 shadow-sm">
				<p class="font-bold text-amber-700">
					ยังไม่พบข้อมูลการตรวจตา ช่องปาก และเท้า สำหรับช่วงเวลาที่เลือก
				</p>
			</section>
		{:else}
			<section class="rounded-[1.75rem] border border-sky-100 bg-white p-5 shadow-sm">
				<div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
					<div>
						<p class="text-sm font-black text-sky-700">ภาพรวมผู้ป่วยในฐานการคัดกรอง</p>
						<div class="mt-2 flex flex-wrap items-end gap-3">
							<p
								class="text-5xl leading-none font-black tracking-tight text-sky-700 [font-variant-numeric:tabular-nums]"
							>
								{formatNumber(clinicPatientTotal)}
							</p>
							<p class="pb-1 text-base font-black text-slate-500">คน</p>
						</div>
						<p class="mt-2 text-sm font-semibold text-slate-500">
							{currentPeriodLabel} | ปีงบประมาณ {selectedYear}
						</p>
					</div>

					<div class="grid grid-cols-1 gap-2 sm:grid-cols-3">
						<div class="rounded-2xl bg-emerald-50 px-4 py-3 text-sm font-black text-emerald-700">
							ตา {formatPercent(eyePercent)}
						</div>
						<div class="rounded-2xl bg-amber-50 px-4 py-3 text-sm font-black text-amber-700">
							ช่องปากและฟัน {formatPercent(oralPercent)}
						</div>
						<div class="rounded-2xl bg-violet-50 px-4 py-3 text-sm font-black text-violet-700">
							เท้า {formatPercent(footPercent)}
						</div>
					</div>
				</div>
			</section>

			<section aria-labelledby="screening-three-domains" class="space-y-4">
				<div class="flex flex-col gap-2 md:flex-row md:items-end md:justify-between">
					<div>
						<h2 id="screening-three-domains" class="text-2xl font-black text-[#063F33]">
							3 ด้านการคัดกรองหลัก
						</h2>
						<p class="mt-1 text-sm font-medium text-slate-500">
							แสดงข้อมูลการตรวจตา ช่องปากและฟัน และเท้าอย่างสมดุลในระดับเดียวกัน
						</p>
					</div>
					<div
						class="rounded-full bg-white px-4 py-2 text-xs font-black text-slate-500 ring-1 ring-slate-100"
					>
						{currentPeriodLabel}
					</div>
				</div>

				<div class="grid grid-cols-1 gap-5 lg:grid-cols-3">
					<article
						class="flex min-h-[260px] min-w-0 flex-col rounded-[1.75rem] border border-emerald-100 bg-white p-5 shadow-sm"
					>
						<div class="flex items-start justify-between gap-4">
							<div>
								<p class="text-xs font-black tracking-wide text-emerald-700 uppercase">
									Eye Screening
								</p>
								<h3 class="mt-1 text-xl font-black text-[#063F33]">ตรวจจอประสาทตา</h3>
								<p class="mt-1 text-sm font-semibold text-slate-500">
									ผู้ป่วยที่ได้รับการตรวจในงวดนี้
								</p>
							</div>
							<div
								class="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-emerald-50 text-emerald-700"
							>
								<Eye aria-hidden="true" size={26} strokeWidth={2.5} />
							</div>
						</div>

						<div class="mt-6 flex flex-wrap items-end gap-2">
							<p
								class="text-5xl leading-none font-black tracking-tight text-emerald-700 [font-variant-numeric:tabular-nums]"
							>
								{formatNumber(eyeCount)}
							</p>
							<p class="pb-1 text-sm font-black text-slate-500">
								/ {formatNumber(eyeRow?.denominator ?? 0)} คน
							</p>
						</div>
						<p class="mt-2 text-2xl font-black text-emerald-700">{formatPercent(eyePercent)}</p>

						<div aria-hidden="true" class="mt-5 h-3 overflow-hidden rounded-full bg-emerald-50">
							<div
								class="h-full rounded-full bg-emerald-500"
								style={`width: ${Math.min(eyePercent, 100)}%`}
							></div>
						</div>

						<div class="mt-auto flex flex-wrap items-center justify-between gap-2 pt-5 text-sm">
							<span class="font-semibold text-slate-500">ยังไม่ได้รับการตรวจ</span>
							<span class="font-black text-emerald-700">{formatNumber(eyePending)} คน</span>
						</div>
					</article>

					<article
						class="flex min-h-[260px] min-w-0 flex-col rounded-[1.75rem] border border-amber-100 bg-white p-5 shadow-sm"
					>
						<div class="flex items-start justify-between gap-4">
							<div>
								<p class="text-xs font-black tracking-wide text-amber-700 uppercase">
									Oral Health Screening
								</p>
								<h3 class="mt-1 text-xl font-black text-[#063F33]">ตรวจสุขภาพช่องปากและฟัน</h3>
								<p class="mt-1 text-sm font-semibold text-slate-500">
									ผู้ป่วยที่ได้รับการตรวจในงวดนี้
								</p>
							</div>
							<div
								class="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-amber-50 text-amber-700"
							>
								<Smile aria-hidden="true" size={26} strokeWidth={2.5} />
							</div>
						</div>

						<div class="mt-6 flex flex-wrap items-end gap-2">
							<p
								class="text-5xl leading-none font-black tracking-tight text-amber-700 [font-variant-numeric:tabular-nums]"
							>
								{formatNumber(oralCount)}
							</p>
							<p class="pb-1 text-sm font-black text-slate-500">
								/ {formatNumber(oralRow?.denominator ?? 0)} คน
							</p>
						</div>
						<p class="mt-2 text-2xl font-black text-amber-700">{formatPercent(oralPercent)}</p>

						<div aria-hidden="true" class="mt-5 h-3 overflow-hidden rounded-full bg-amber-50">
							<div
								class="h-full rounded-full bg-amber-500"
								style={`width: ${Math.min(oralPercent, 100)}%`}
							></div>
						</div>

						<div class="mt-auto flex flex-wrap items-center justify-between gap-2 pt-5 text-sm">
							<span class="font-semibold text-slate-500">ยังไม่ได้รับการตรวจ</span>
							<span class="font-black text-amber-700">{formatNumber(oralPending)} คน</span>
						</div>
					</article>

					<article
						class="flex min-h-[260px] min-w-0 flex-col rounded-[1.75rem] border border-violet-100 bg-white p-5 shadow-sm"
					>
						<div class="flex items-start justify-between gap-4">
							<div>
								<p class="text-xs font-black tracking-wide text-violet-700 uppercase">
									Foot Screening
								</p>
								<h3 class="mt-1 text-xl font-black text-[#063F33]">ตรวจเท้า</h3>
								<p class="mt-1 text-sm font-semibold text-slate-500">
									ผู้ป่วยที่ได้รับการตรวจในงวดนี้
								</p>
							</div>
							<div
								class="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-violet-50 text-violet-700"
							>
								<Footprints aria-hidden="true" size={26} strokeWidth={2.5} />
							</div>
						</div>

						<div class="mt-6 flex flex-wrap items-end gap-2">
							<p
								class="text-5xl leading-none font-black tracking-tight text-violet-700 [font-variant-numeric:tabular-nums]"
							>
								{formatNumber(footCount)}
							</p>
							<p class="pb-1 text-sm font-black text-slate-500">
								/ {formatNumber(footRow?.denominator ?? 0)} คน
							</p>
						</div>
						<p class="mt-2 text-2xl font-black text-violet-700">{formatPercent(footPercent)}</p>

						<div aria-hidden="true" class="mt-5 h-3 overflow-hidden rounded-full bg-violet-50">
							<div
								class="h-full rounded-full bg-violet-500"
								style={`width: ${Math.min(footPercent, 100)}%`}
							></div>
						</div>

						<div class="mt-auto flex flex-wrap items-center justify-between gap-2 pt-5 text-sm">
							<span class="font-semibold text-slate-500">ยังไม่ได้รับการตรวจ</span>
							<span class="font-black text-violet-700">{formatNumber(footPending)} คน</span>
						</div>
					</article>
				</div>
			</section>

			<section class="grid w-full grid-cols-1 items-stretch gap-5 lg:grid-cols-12">
				<div
					class="min-w-0 rounded-[1.75rem] border border-emerald-100 bg-white p-5 shadow-sm lg:col-span-7"
				>
					<div class="mb-5 flex flex-col gap-3">
						<div class="flex items-center gap-3">
							<div
								class="grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-emerald-50 text-emerald-700"
							>
								<TrendingUp aria-hidden="true" size={23} strokeWidth={2.5} />
							</div>
							<div>
								<h2 class="text-2xl font-black text-[#063F33]">ความครอบคลุมการคัดกรอง</h2>
								<p class="mt-1 text-sm font-medium text-slate-500">
									เปรียบเทียบสัดส่วนผู้ป่วยที่ได้รับการตรวจทั้ง 3 ด้าน
								</p>
							</div>
						</div>
						<div class="rounded-full bg-emerald-50 px-4 py-2 text-sm font-bold text-emerald-700">
							{currentPeriodLabel}
						</div>
					</div>
					<ScreeningCoverageChart rows={screeningRows} />
				</div>

				<div
					class="min-w-0 rounded-[1.75rem] border border-slate-100 bg-white p-5 shadow-sm lg:col-span-5"
				>
					<div class="flex items-center gap-3">
						<div
							class="grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-slate-50 text-slate-600"
						>
							<CalendarRange aria-hidden="true" size={22} strokeWidth={2.5} />
						</div>
						<div>
							<h2 class="text-xl font-black text-[#063F33]">สรุปการเข้าถึงบริการ 3 ด้าน</h2>
							<p class="mt-1 text-sm font-medium text-slate-500">
								มองพร้อมกันทั้งจำนวนที่ตรวจแล้วและจำนวนที่ยังไม่ได้รับการตรวจ
							</p>
						</div>
					</div>

					<div class="mt-5 grid grid-cols-1 gap-3">
						<div class="rounded-2xl border border-emerald-100 bg-emerald-50/60 p-4">
							<div class="flex items-center justify-between gap-3">
								<div class="flex items-center gap-3">
									<Eye aria-hidden="true" size={21} class="text-emerald-700" />
									<span class="font-black text-slate-700">ตา</span>
								</div>
								<span class="text-sm font-black text-emerald-700">{formatPercent(eyePercent)}</span>
							</div>
							<div
								class="mt-3 flex flex-wrap items-center justify-between gap-2 text-xs font-bold text-slate-500"
							>
								<span>ตรวจแล้ว {formatNumber(eyeCount)}</span>
								<span>ยังไม่ได้ตรวจ {formatNumber(eyePending)}</span>
							</div>
						</div>

						<div class="rounded-2xl border border-amber-100 bg-amber-50/60 p-4">
							<div class="flex items-center justify-between gap-3">
								<div class="flex items-center gap-3">
									<Smile aria-hidden="true" size={21} class="text-amber-700" />
									<span class="font-black text-slate-700">ช่องปากและฟัน</span>
								</div>
								<span class="text-sm font-black text-amber-700">{formatPercent(oralPercent)}</span>
							</div>
							<div
								class="mt-3 flex flex-wrap items-center justify-between gap-2 text-xs font-bold text-slate-500"
							>
								<span>ตรวจแล้ว {formatNumber(oralCount)}</span>
								<span>ยังไม่ได้ตรวจ {formatNumber(oralPending)}</span>
							</div>
						</div>

						<div class="rounded-2xl border border-violet-100 bg-violet-50/60 p-4">
							<div class="flex items-center justify-between gap-3">
								<div class="flex items-center gap-3">
									<Footprints aria-hidden="true" size={21} class="text-violet-700" />
									<span class="font-black text-slate-700">เท้า</span>
								</div>
								<span class="text-sm font-black text-violet-700">{formatPercent(footPercent)}</span>
							</div>
							<div
								class="mt-3 flex flex-wrap items-center justify-between gap-2 text-xs font-bold text-slate-500"
							>
								<span>ตรวจแล้ว {formatNumber(footCount)}</span>
								<span>ยังไม่ได้ตรวจ {formatNumber(footPending)}</span>
							</div>
						</div>
					</div>
				</div>
			</section>

			<section class="rounded-[1.75rem] border border-sky-100 bg-white p-5 shadow-sm">
				<div class="mb-5 flex flex-col gap-3">
					<div class="flex items-center gap-3">
						<div
							class="grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-sky-50 text-sky-700"
						>
							<TrendingUp aria-hidden="true" size={23} strokeWidth={2.5} />
						</div>
						<div>
							<h2 class="text-2xl font-black text-[#063F33]">แนวโน้มการคัดกรองรายไตรมาส</h2>
							<p class="mt-1 text-sm font-medium text-slate-500">
								ช่วยให้เห็นทิศทางการเข้าถึงบริการตลอดปีงบประมาณ
							</p>
						</div>
					</div>
					<div class="rounded-full bg-sky-50 px-4 py-2 text-sm font-bold text-sky-700">
						ปีงบประมาณ {selectedYear}
					</div>
				</div>
				<div class="grid grid-cols-1 items-stretch gap-4 lg:grid-cols-3">
					{#each [{ no: 13, title: 'ตรวจจอประสาทตา', color: 'text-emerald-700', border: 'border-emerald-100', icon: Eye }, { no: 14, title: 'ตรวจสุขภาพช่องปากและฟัน', color: 'text-amber-700', border: 'border-amber-100', icon: Smile }, { no: 15, title: 'ตรวจเท้า', color: 'text-violet-700', border: 'border-violet-100', icon: Footprints }] as domain (domain.no)}
						<article class={'min-w-0 rounded-2xl border bg-white p-4 ' + domain.border}>
							<h3 class={'flex min-h-14 items-center gap-3 text-lg font-black ' + domain.color}>
								<domain.icon size={24} aria-hidden="true" class="shrink-0" />
								{domain.title}
							</h3>
							<p class="mt-1 text-xs font-medium text-slate-500">
								สัดส่วนผู้ป่วยที่ได้รับการตรวจ • ปีงบประมาณ {selectedYear}
							</p>
							<ScreeningTrendChart {rows} year={selectedYear} indicatorNo={domain.no} />
						</article>
					{/each}
				</div>
			</section>

			<details bind:open={footRiskOpen} class="rounded-2xl border border-slate-200 bg-white p-5">
				<summary
					class="cursor-pointer rounded-lg text-base font-bold text-slate-700 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-emerald-700"
				>
					รายละเอียดเพิ่มเติม: ผลประเมินความเสี่ยงเท้า
					<span class="mt-2 block text-sm font-medium text-slate-500">
						{#if footRiskError}ยังไม่สามารถโหลดข้อมูลความเสี่ยงเท้าได้
						{:else if currentFootRiskRows.length === 0}ยังไม่มีข้อมูลผลประเมินในช่วงเวลานี้
						{:else}มีผลประเมิน {formatNumber(footRiskTotal)} HN{/if}
						· {currentPeriodLabel} · {footRiskOpen ? 'กดเพื่อย่อรายละเอียด' : 'กดเพื่อดูรายละเอียด'}
					</span>
				</summary>
				{#if footRiskOpen}
					<div class="mt-5 border-t border-slate-100 pt-5">
						{#if footRiskError}
							<div class="rounded-3xl border border-amber-100 bg-amber-50 p-5">
								<p class="font-bold text-amber-700">ยังไม่สามารถแสดงข้อมูลความเสี่ยงเท้าได้</p>
								<p class="mt-1 text-sm font-semibold text-slate-500">{footRiskError}</p>
							</div>
						{:else}
							<div class="grid w-full grid-cols-1 items-stretch gap-5 lg:grid-cols-12">
								<div
									class="min-w-0 rounded-3xl border border-slate-100 bg-slate-50/40 p-4 lg:col-span-7"
								>
									<FootRiskChart rows={currentFootRiskRows} />
								</div>

								<div
									class="min-w-0 rounded-3xl border border-amber-100 bg-amber-50/50 p-5 lg:col-span-5"
								>
									<div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
										{#each currentFootRiskRows as row (row.risk_code)}
											<div class="rounded-2xl bg-white p-4 ring-1 ring-slate-100">
												<p class="text-xs font-black text-slate-500">{row.risk_code}</p>
												<p class="mt-1 text-sm font-black text-slate-700">{row.risk_name}</p>
												<p class="mt-3 text-3xl font-black text-slate-800">
													{formatNumber(row.total_hn)}
												</p>
												<p class="text-xs font-bold text-slate-500">HN</p>
											</div>
										{/each}
									</div>

									<div class="mt-4 rounded-2xl bg-white p-4 ring-1 ring-amber-100">
										<p class="text-xs font-black text-slate-500">
											ผู้ป่วยที่มีผลประเมินความเสี่ยงเท้า
										</p>
										<p class="mt-1 text-3xl font-black text-amber-700">
											{formatNumber(footRiskTotal)} HN
										</p>
										<p class="mt-2 text-sm font-semibold text-slate-500">
											กลุ่มเสี่ยงสูงและสูงมาก {formatNumber(footHighRiskTotal)} HN ({formatPercent(
												footHighRiskPercent
											)})
										</p>
									</div>
								</div>
							</div>
						{/if}
					</div>
				{/if}
			</details>
		{/if}
	</div>
</main>
