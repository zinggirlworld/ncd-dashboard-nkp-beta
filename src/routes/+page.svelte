<script lang="ts">
	import { base } from '$app/paths';
	import { onMount } from 'svelte';
	import { loadFootRiskSummary, type FootRiskRow, type PeriodType } from '$lib/footRiskData';
	import FootRiskChart from '$lib/components/FootRiskChart.svelte';
	import {
		AlertTriangle,
		CalendarRange,
		CheckCircle2,
		CircleGauge,
		Footprints,
		ShieldAlert,
		UsersRound
	} from 'lucide-svelte';

	const riskLevels = [
		{ risk_code: 'Z0280', risk_name: 'เสี่ยงต่ำ', risk_order: 1 },
		{ risk_code: 'Z0281', risk_name: 'เสี่ยงปานกลาง', risk_order: 2 },
		{ risk_code: 'Z0282', risk_name: 'เสี่ยงสูง', risk_order: 3 },
		{ risk_code: 'Z0283', risk_name: 'เสี่ยงสูงมาก', risk_order: 4 }
	] as const;

	let rows = $state<FootRiskRow[]>([]);
	let loading = $state(true);
	let errorMessage = $state('');
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
				return a.risk_order - b.risk_order;
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

	let selectedRowsRaw = $derived(
		selectedPeriodType === 'ไตรมาส'
			? filteredRows.filter((row) => row.period_order === activePeriodOrder)
			: filteredRows
	);

	let currentRows = $derived.by(() => {
		const periodLabel =
			selectedRowsRaw[0]?.period_label ??
			availablePeriods.find((period) => period.order === activePeriodOrder)?.label ??
			selectedPeriodType;

		return riskLevels.map((level) => {
			const found = selectedRowsRaw.find((row) => row.risk_code === level.risk_code);
			return (
				found ?? {
					period_type: selectedPeriodType,
					fiscal_year_be: selectedYear,
					period_order: activePeriodOrder,
					period_label: periodLabel,
					risk_code: level.risk_code,
					risk_name: level.risk_name,
					risk_order: level.risk_order,
					total_hn: 0
				}
			);
		});
	});

	let currentPeriodLabel = $derived(
		selectedRowsRaw[0]?.period_label ??
			availablePeriods.find((period) => period.order === activePeriodOrder)?.label ??
			selectedPeriodType
	);

	let totalHn = $derived(currentRows.reduce((sum, row) => sum + row.total_hn, 0));
	let lowRiskHn = $derived(currentRows.find((row) => row.risk_code === 'Z0280')?.total_hn ?? 0);
	let moderateRiskHn = $derived(
		currentRows.find((row) => row.risk_code === 'Z0281')?.total_hn ?? 0
	);
	let highRiskHn = $derived(currentRows.find((row) => row.risk_code === 'Z0282')?.total_hn ?? 0);
	let veryHighRiskHn = $derived(
		currentRows.find((row) => row.risk_code === 'Z0283')?.total_hn ?? 0
	);
	let highOrVeryHighHn = $derived(highRiskHn + veryHighRiskHn);
	let highOrVeryHighPercent = $derived(totalHn > 0 ? (highOrVeryHighHn * 100) / totalHn : 0);
	let hasData = $derived(selectedRowsRaw.some((row) => row.total_hn > 0));

	function formatNumber(value: number): string {
		return value.toLocaleString('th-TH');
	}

	function formatPercent(value: number): string {
		return `${value.toLocaleString('th-TH', {
			minimumFractionDigits: 2,
			maximumFractionDigits: 2
		})}%`;
	}

	function riskPercent(value: number): number {
		return totalHn > 0 ? (value * 100) / totalHn : 0;
	}

	function handlePeriodOrderChange(event: Event) {
		selectedPeriodOrder = Number((event.currentTarget as HTMLSelectElement).value);
	}

	onMount(async () => {
		try {
			rows = await loadFootRiskSummary();
			const availableYears = [...new Set(rows.map((row) => row.fiscal_year_be))]
				.filter((year) => year > 0)
				.sort((a, b) => b - a);
			if (availableYears.length > 0) selectedYear = availableYears[0];
		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'โหลดข้อมูลความเสี่ยงเท้าไม่สำเร็จ';
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>Dashboard การประเมินความเสี่ยงเท้าในผู้ป่วยเบาหวาน</title>
	<meta
		name="description"
		content="Dashboard สรุปผลการประเมินความเสี่ยงเท้าในผู้ป่วยเบาหวาน คลินิกเบาหวาน โรงพยาบาลนครพิงค์"
	/>
</svelte:head>

<main class="min-h-screen bg-[#EAF7F2] px-4 py-5 text-slate-800 md:px-8">
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
							<p class="text-xs font-bold text-emerald-700">Diabetic Foot Risk Dashboard</p>
						</div>
					</div>

					<h1 class="mt-4 text-2xl leading-tight font-black text-[#063F33] md:text-3xl">
						ผลการประเมินความเสี่ยงเท้าในผู้ป่วยเบาหวาน
					</h1>
					<p class="mt-2 text-sm font-semibold text-emerald-800 md:text-base">
						คลินิกเบาหวาน โรงพยาบาลนครพิงค์ | แสดงจำนวน HN ไม่ซ้ำตามระดับความเสี่ยง
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
							disabled={years.length === 0}
							onchange={() => (selectedPeriodOrder = null)}
						>
							{#if years.length === 0}
								<option value={selectedYear}>{selectedYear}</option>
							{:else}
								{#each years as year (year)}
									<option value={year}>{year}</option>
								{/each}
							{/if}
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
			<section role="alert" class="rounded-3xl border border-rose-100 bg-white p-6 shadow-sm">
				<div class="flex items-start gap-3">
					<ShieldAlert class="mt-0.5 text-rose-600" aria-hidden="true" size={22} />
					<div>
						<p class="font-black text-rose-700">ไม่สามารถโหลดข้อมูลได้</p>
						<p class="mt-1 text-sm font-semibold text-slate-600">{errorMessage}</p>
					</div>
				</div>
			</section>
		{:else if !hasData}
			<section class="rounded-[1.75rem] border border-amber-200 bg-white p-6 shadow-sm">
				<div class="flex flex-col gap-5 md:flex-row md:items-center md:justify-between">
					<div class="flex items-start gap-4">
						<div
							class="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-amber-50 text-amber-700"
						>
							<AlertTriangle aria-hidden="true" size={24} strokeWidth={2.5} />
						</div>
						<div>
							<h2 class="text-xl font-black text-slate-800">รอข้อมูลจาก Query ฉบับใหม่</h2>
							<p class="mt-2 max-w-3xl text-sm leading-6 font-semibold text-slate-600">
								ไฟล์ข้อมูลเดิมถูกพักการใช้งานเพื่อไม่ให้แสดงจำนวนที่ยังไม่ผ่านการ reconciliation
								ให้รัน <code class="rounded bg-slate-100 px-1.5 py-0.5"
									>sql/foot_risk_summary_export_no_bom.sql</code
								>
								แล้วบันทึกผลเป็น
								<code class="rounded bg-slate-100 px-1.5 py-0.5">static/foot_risk_summary.csv</code>
							</p>
						</div>
					</div>
					<div
						class="rounded-2xl bg-amber-50 px-4 py-3 text-sm font-black text-amber-800 ring-1 ring-amber-100"
					>
						Data correctness gate
					</div>
				</div>
			</section>
		{:else}
			<section class="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-6">
				<div
					class="rounded-[1.5rem] border border-sky-100 bg-white p-5 shadow-sm sm:col-span-2 xl:col-span-2"
				>
					<div class="flex items-start justify-between gap-3">
						<div>
							<p class="text-sm font-black text-slate-500">ผู้ป่วยที่มีผลประเมินความเสี่ยงเท้า</p>
							<p class="mt-3 text-5xl font-black tracking-tight text-sky-700">
								{formatNumber(totalHn)}
							</p>
							<p class="mt-1 text-sm font-bold text-slate-500">HN ไม่ซ้ำ</p>
						</div>
						<div class="grid h-11 w-11 place-items-center rounded-2xl bg-sky-50 text-sky-700">
							<UsersRound aria-hidden="true" size={22} strokeWidth={2.5} />
						</div>
					</div>
					<p class="mt-4 text-xs font-bold text-slate-400">
						{currentPeriodLabel} | ปีงบประมาณ {selectedYear}
					</p>
				</div>

				<div class="rounded-[1.5rem] border border-emerald-100 bg-white p-5 shadow-sm">
					<p class="text-sm font-black text-emerald-700">เสี่ยงต่ำ</p>
					<p class="mt-3 text-4xl font-black text-emerald-700">{formatNumber(lowRiskHn)}</p>
					<p class="mt-2 text-sm font-bold text-slate-500">
						{formatPercent(riskPercent(lowRiskHn))}
					</p>
				</div>

				<div class="rounded-[1.5rem] border border-amber-100 bg-white p-5 shadow-sm">
					<p class="text-sm font-black text-amber-700">เสี่ยงปานกลาง</p>
					<p class="mt-3 text-4xl font-black text-amber-700">{formatNumber(moderateRiskHn)}</p>
					<p class="mt-2 text-sm font-bold text-slate-500">
						{formatPercent(riskPercent(moderateRiskHn))}
					</p>
				</div>

				<div class="rounded-[1.5rem] border border-orange-100 bg-white p-5 shadow-sm">
					<p class="text-sm font-black text-orange-700">เสี่ยงสูง</p>
					<p class="mt-3 text-4xl font-black text-orange-700">{formatNumber(highRiskHn)}</p>
					<p class="mt-2 text-sm font-bold text-slate-500">
						{formatPercent(riskPercent(highRiskHn))}
					</p>
				</div>

				<div class="rounded-[1.5rem] border border-rose-100 bg-white p-5 shadow-sm">
					<p class="text-sm font-black text-rose-700">เสี่ยงสูงมาก</p>
					<p class="mt-3 text-4xl font-black text-rose-700">{formatNumber(veryHighRiskHn)}</p>
					<p class="mt-2 text-sm font-bold text-slate-500">
						{formatPercent(riskPercent(veryHighRiskHn))}
					</p>
				</div>
			</section>

			<section class="grid grid-cols-1 gap-5 xl:grid-cols-[1.45fr_0.75fr]">
				<div class="rounded-[1.75rem] border border-emerald-100 bg-white p-5 shadow-sm">
					<div class="mb-5 flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
						<div class="flex items-center gap-3">
							<div
								class="grid h-11 w-11 place-items-center rounded-2xl bg-emerald-50 text-emerald-700"
							>
								<Footprints aria-hidden="true" size={23} strokeWidth={2.5} />
							</div>
							<div>
								<h2 class="text-2xl font-black text-[#063F33]">สัดส่วนระดับความเสี่ยงเท้า</h2>
								<p class="mt-1 text-sm font-medium text-slate-500">
									ผู้ป่วย 1 HN นับเพียง 1 ระดับต่อหนึ่งงวดข้อมูล
								</p>
							</div>
						</div>
						<div class="rounded-full bg-emerald-50 px-4 py-2 text-sm font-bold text-emerald-700">
							{currentPeriodLabel}
						</div>
					</div>
					<FootRiskChart rows={currentRows} />
				</div>

				<div
					class="rounded-[1.75rem] border border-rose-100 bg-gradient-to-b from-rose-50 to-white p-5 shadow-sm"
				>
					<div class="flex items-center gap-3">
						<div
							class="grid h-11 w-11 place-items-center rounded-2xl bg-white text-rose-600 ring-1 ring-rose-100"
						>
							<CircleGauge aria-hidden="true" size={22} strokeWidth={2.5} />
						</div>
						<div>
							<p class="text-sm font-black text-rose-700">รวมกลุ่มเสี่ยงสูงและสูงมาก</p>
							<h2 class="mt-1 text-xl font-black text-slate-800">เสี่ยงสูง + เสี่ยงสูงมาก</h2>
						</div>
					</div>

					<p class="mt-6 text-5xl font-black tracking-tight text-rose-600">
						{formatNumber(highOrVeryHighHn)}
					</p>
					<p class="mt-1 font-bold text-slate-500">HN</p>
					<div class="mt-5 rounded-2xl bg-white p-4 ring-1 ring-rose-100">
						<p class="text-xs font-black text-slate-500">คิดเป็น</p>
						<p class="mt-1 text-3xl font-black text-rose-600">
							{formatPercent(highOrVeryHighPercent)}
						</p>
						<p class="mt-2 text-sm font-semibold text-slate-500">
							ของผู้ป่วยที่มีผลประเมินในงวดนี้
						</p>
					</div>
				</div>
			</section>

			<section class="rounded-[1.75rem] border border-slate-100 bg-white p-5 shadow-sm">
				<div class="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
					<div class="flex items-center gap-3">
						<div class="grid h-11 w-11 place-items-center rounded-2xl bg-slate-50 text-slate-600">
							<CalendarRange aria-hidden="true" size={22} strokeWidth={2.5} />
						</div>
						<div>
							<h2 class="text-xl font-black text-[#063F33]">รายละเอียดงวดข้อมูล</h2>
							<p class="mt-1 text-sm font-medium text-slate-500">
								จำนวนและสัดส่วนแยกตามรหัสความเสี่ยง
							</p>
						</div>
					</div>
					<div
						class="rounded-full bg-slate-50 px-4 py-2 text-xs font-black text-slate-600 ring-1 ring-slate-100"
					>
						รวม {formatNumber(totalHn)} HN
					</div>
				</div>

				<div class="mt-5 overflow-x-auto rounded-2xl border border-slate-100">
					<table class="w-full min-w-[680px] border-separate border-spacing-0 text-left text-sm">
						<caption class="sr-only">รายละเอียดจำนวนผู้ป่วยตามระดับความเสี่ยงเท้า</caption>
						<thead>
							<tr class="bg-emerald-50 text-emerald-900">
								<th scope="col" class="px-4 py-3">รหัส</th>
								<th scope="col" class="px-4 py-3">ระดับความเสี่ยง</th>
								<th scope="col" class="px-4 py-3 text-right">จำนวน HN</th>
								<th scope="col" class="px-4 py-3 text-right">สัดส่วน</th>
							</tr>
						</thead>
						<tbody>
							{#each currentRows as row (row.risk_code)}
								<tr class="border-b bg-white even:bg-slate-50/50">
									<td class="px-4 py-3 font-black text-slate-600">{row.risk_code}</td>
									<td class="px-4 py-3 font-bold text-slate-800">{row.risk_name}</td>
									<td class="px-4 py-3 text-right font-black text-slate-800"
										>{formatNumber(row.total_hn)}</td
									>
									<td class="px-4 py-3 text-right font-black text-slate-600"
										>{formatPercent(riskPercent(row.total_hn))}</td
									>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</section>

			<section class="rounded-[1.75rem] border border-emerald-100 bg-white p-5 shadow-sm">
				<div class="flex items-start gap-3">
					<div
						class="grid h-10 w-10 shrink-0 place-items-center rounded-2xl bg-emerald-50 text-emerald-700"
					>
						<CheckCircle2 aria-hidden="true" size={21} strokeWidth={2.5} />
					</div>
					<div>
						<h2 class="text-lg font-black text-[#063F33]">กติกาการนับที่ใช้ใน Query ฉบับใหม่</h2>
						<p class="mt-2 text-sm leading-6 font-semibold text-slate-600">
							นับ HN ไม่ซ้ำภายในแต่ละงวด, จำกัดเฉพาะผู้ป่วยที่อยู่ใน cohort DM ของคลินิก 0105
							ในงวดเดียวกัน, และเมื่อ HN เดียวมีหลายรหัส Z0280–Z0283 ในงวดเดียวกัน
							จะเลือกความเสี่ยงสูงสุดเพียงระดับเดียว เพื่อลดการนับซ้ำ
						</p>
						<p class="mt-2 text-xs leading-5 font-semibold text-slate-400">
							จำนวนระดับปีงบประมาณและรายไตรมาสคำนวณด้วย population fence ของงวดนั้นโดยอิสระ
							จึงไม่ควรนำผลรวม 4 ไตรมาสมาใช้แทนจำนวน HN ของทั้งปีงบประมาณ
						</p>
					</div>
				</div>
			</section>
		{/if}
	</div>
</main>
