<script lang="ts">
	import * as echarts from 'echarts';
	import type { ECharts, EChartsOption } from 'echarts';
	import type { FootRiskRow } from '$lib/footRiskData';

	let {
		rows = []
	}: {
		rows?: FootRiskRow[];
	} = $props();

	let chartEl = $state<HTMLDivElement | null>(null);
	let chart: ECharts | null = null;

	let chartRows = $derived(
		rows.filter((row) => row.total_hn > 0).sort((a, b) => a.risk_order - b.risk_order)
	);
	let hasData = $derived(chartRows.length > 0);
	let totalHn = $derived(chartRows.reduce((sum, row) => sum + row.total_hn, 0));
	let highRiskHn = $derived(
		chartRows
			.filter((row) => row.risk_code === 'Z0282' || row.risk_code === 'Z0283')
			.reduce((sum, row) => sum + row.total_hn, 0)
	);

	function riskColor(code: string): string {
		if (code === 'Z0280') return '#10B981';
		if (code === 'Z0281') return '#F59E0B';
		if (code === 'Z0282') return '#F97316';
		if (code === 'Z0283') return '#EF4444';
		return '#94A3B8';
	}

	function formatNumber(value: number): string {
		return value.toLocaleString('th-TH');
	}

	function buildOptions(): EChartsOption {
		return {
			backgroundColor: 'transparent',
			tooltip: {
				trigger: 'axis',
				axisPointer: { type: 'shadow' },
				borderColor: '#E2E8F0',
				borderWidth: 1,
				backgroundColor: 'rgba(255,255,255,0.98)',
				textStyle: { fontFamily: 'Tahoma', color: '#334155', fontWeight: 700 },
				formatter: (params) => {
					const items = Array.isArray(params) ? params : [params];
					const item = items[0] as { dataIndex?: number };
					const row = chartRows[item.dataIndex ?? 0];
					if (!row) return '';
					return [
						`<strong>${row.risk_code} · ${row.risk_name}</strong>`,
						`จำนวน ${formatNumber(row.total_hn)} HN`
					].join('<br/>');
				}
			},
			grid: { left: 150, right: 80, top: 20, bottom: 24, containLabel: false },
			xAxis: {
				type: 'value',
				min: 0,
				axisLabel: {
					fontFamily: 'Tahoma',
					fontWeight: 700,
					color: '#64748B'
				},
				splitLine: { lineStyle: { color: '#E2E8F0', type: 'dashed' } }
			},
			yAxis: {
				type: 'category',
				inverse: true,
				data: chartRows.map((row) => `${row.risk_code}  ${row.risk_name}`),
				axisLabel: {
					fontFamily: 'Tahoma',
					fontWeight: 700,
					color: '#334155',
					width: 130,
					overflow: 'break'
				},
				axisTick: { show: false },
				axisLine: { show: false }
			},
			series: [
				{
					type: 'bar',
					data: chartRows.map((row) => ({
						value: row.total_hn,
						itemStyle: { color: riskColor(row.risk_code), borderRadius: [0, 10, 10, 0] }
					})),
					barWidth: 24,
					showBackground: true,
					backgroundStyle: {
						color: '#F1F5F9',
						borderRadius: 10
					},
					label: {
						show: true,
						position: 'right',
						distance: 10,
						formatter: (params) => `${Number(params.value).toLocaleString('th-TH')} HN`,
						fontFamily: 'Tahoma',
						fontWeight: 800,
						color: '#334155'
					}
				}
			]
		};
	}

	$effect(() => {
		if (!chartEl) return;

		const instance = echarts.init(chartEl);
		chart = instance;

		const handleResize = () => instance.resize();
		const observer = new ResizeObserver(handleResize);
		observer.observe(chartEl);

		return () => {
			observer.disconnect();
			instance.dispose();
			if (chart === instance) chart = null;
		};
	});

	$effect(() => {
		if (!chart || !hasData) return;
		chart.setOption(buildOptions(), true);
	});
</script>

{#if hasData}
	<div class="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1fr)_280px] lg:items-stretch">
		<div class="min-w-0 rounded-3xl border border-slate-100 bg-slate-50/40 p-4">
			<div
				role="img"
				aria-label="กราฟแท่งแนวนอนแสดงจำนวน HN ตามระดับความเสี่ยงเท้า"
				class="h-[300px] w-full sm:h-[320px]"
				bind:this={chartEl}
			></div>
		</div>

		<aside class="flex flex-col justify-center rounded-3xl border border-rose-100 bg-rose-50 p-5">
			<p class="text-sm font-black text-rose-700">กลุ่มเสี่ยงสูง + เสี่ยงสูงมาก</p>
			<p class="mt-3 text-5xl font-black tracking-tight text-rose-600 [font-variant-numeric:tabular-nums]">
				{formatNumber(highRiskHn)} HN
			</p>
			<p class="mt-3 text-sm font-semibold text-slate-600">Z0282 + Z0283</p>
			<div class="mt-5 border-t border-rose-100 pt-4">
				<p class="text-xs font-bold text-slate-500">ผู้ป่วยที่มีผลประเมินความเสี่ยงเท้าทั้งหมด</p>
				<p class="mt-1 text-2xl font-black text-slate-800">{formatNumber(totalHn)} HN</p>
			</div>
		</aside>
	</div>
{:else}
	<div
		class="grid h-[280px] w-full place-items-center rounded-3xl border border-dashed border-amber-200 bg-amber-50/40"
	>
		<div class="text-center">
			<p role="status" class="text-base font-black text-amber-700">ยังไม่มีข้อมูลความเสี่ยงเท้า</p>
			<p class="mt-1 text-sm font-semibold text-slate-500">
				กรุณาเลือกปีงบประมาณหรือไตรมาสอื่น หรือลองโหลดหน้าเว็บใหม่
			</p>
		</div>
	</div>
{/if}
