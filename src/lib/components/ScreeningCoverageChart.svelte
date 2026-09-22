<script lang="ts">
	import * as echarts from 'echarts';
	import type { ECharts, EChartsOption } from 'echarts';
	import type { NcdIndicator } from '$lib/data';

	let { rows = [] }: { rows?: NcdIndicator[] } = $props();

	let chartEl = $state<HTMLDivElement | null>(null);
	let chart: ECharts | null = null;

	function labelFor(indicatorNo: number): string {
		if (indicatorNo === 13) return 'ตรวจตา';
		if (indicatorNo === 14) return 'ตรวจช่องปากและฟัน';
		if (indicatorNo === 15) return 'ตรวจเท้า';
		return '';
	}

	let chartRows = $derived(
		rows
			.filter((row) => [13, 14, 15].includes(row.indicator_no))
			.filter((row) => row.actual_percent !== null)
			.sort((a, b) => a.indicator_no - b.indicator_no)
	);

	let hasData = $derived(chartRows.length > 0);

	function buildOptions(): EChartsOption {
		const colors = ['#10B981', '#F59E0B', '#8B5CF6'];

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
						`<strong>${labelFor(row.indicator_no)}</strong>`,
						`ได้รับการตรวจ ${Number(row.numerator ?? 0).toLocaleString('th-TH')} คน`,
						`จาก ${Number(row.denominator ?? 0).toLocaleString('th-TH')} คน`,
						`คิดเป็น ${Number(row.actual_percent ?? 0).toFixed(2)}%`
					].join('<br/>');
				}
			},
			grid: { left: 44, right: 16, top: 28, bottom: 64 },
			xAxis: {
				type: 'category',
				data: chartRows.map((row) => labelFor(row.indicator_no)),
				axisLabel: {
					fontFamily: 'Tahoma',
					fontWeight: 700,
					color: '#475569',
					interval: 0,
					formatter: (value: string) =>
						value === 'ตรวจช่องปากและฟัน' ? 'ตรวจช่องปาก\nและฟัน' : value
				},
				axisLine: { lineStyle: { color: '#CBD5E1' } }
			},
			yAxis: {
				type: 'value',
				min: 0,
				max: 100,
				axisLabel: {
					formatter: '{value}%',
					fontFamily: 'Tahoma',
					fontWeight: 700,
					color: '#64748B'
				},
				splitLine: { lineStyle: { color: '#E2E8F0', type: 'dashed' } }
			},
			series: [
				{
					type: 'bar',
					data: chartRows.map((row) => row.actual_percent ?? 0),
					barMaxWidth: 54,
					itemStyle: {
						color: (params) => colors[params.dataIndex] ?? '#0EA5E9',
						borderRadius: [14, 14, 4, 4]
					},
					label: {
						show: true,
						position: 'top',
						formatter: (params) => `${Number(params.value).toFixed(1)}%`,
						fontFamily: 'Tahoma',
						fontWeight: 800,
						color: '#0F172A'
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
		window.addEventListener('resize', handleResize);

		return () => {
			window.removeEventListener('resize', handleResize);
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
	<div
		role="img"
		aria-label="กราฟเปรียบเทียบความครอบคลุมการตรวจตา ตรวจสุขภาพช่องปากและฟัน และตรวจเท้า"
		class="h-[320px] w-full sm:h-[350px]"
		bind:this={chartEl}
	></div>
{:else}
	<div class="grid h-[280px] place-items-center rounded-3xl border border-dashed border-slate-200">
		<p role="status" class="font-bold text-slate-500">ไม่มีข้อมูลการคัดกรองสำหรับช่วงเวลานี้</p>
	</div>
{/if}
