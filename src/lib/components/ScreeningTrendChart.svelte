<script lang="ts">
	import * as echarts from 'echarts';
	import type { ECharts, EChartsOption } from 'echarts';
	import type { NcdIndicator } from '$lib/data';

	let {
		rows = [],
		year,
		indicatorNo
	}: {
		rows?: NcdIndicator[];
		year: number;
		indicatorNo: number;
	} = $props();

	let chartEl = $state<HTMLDivElement | null>(null);
	let chart = $state.raw<ECharts | null>(null);

	function valuesFor(indicatorNo: number): Array<number | null> {
		return [1, 2, 3, 4].map((quarter) => {
			const row = rows.find(
				(item) =>
					item.fiscal_year_be === year &&
					item.period_type === 'ไตรมาส' &&
					item.period_order === quarter &&
					item.indicator_no === indicatorNo
			);
			return row?.actual_percent ?? null;
		});
	}

	let eyeValues = $derived(valuesFor(13));
	let oralValues = $derived(valuesFor(14));
	let footValues = $derived(valuesFor(15));

	let selectedValues = $derived(
		indicatorNo === 13 ? eyeValues : indicatorNo === 14 ? oralValues : footValues
	);
	let domainLabel = $derived(
		indicatorNo === 13 ? 'ตรวจตา' : indicatorNo === 14 ? 'ตรวจช่องปากและฟัน' : 'ตรวจเท้า'
	);
	let hasData = $derived(selectedValues.some((value) => value !== null));

	function buildOptions(): EChartsOption {
		return {
			backgroundColor: 'transparent',
			tooltip: {
				trigger: 'axis',
				borderColor: '#E2E8F0',
				borderWidth: 1,
				backgroundColor: 'rgba(255,255,255,0.98)',
				textStyle: { fontFamily: 'Tahoma', color: '#334155', fontWeight: 700 },
				valueFormatter: (value) =>
					value === null || value === undefined ? '-' : `${Number(value).toFixed(2)}%`
			},
			legend: {
				show: false,
				textStyle: { fontFamily: 'Tahoma', fontWeight: 700, color: '#475569' }
			},
			grid: { left: 44, right: 16, top: 24, bottom: 36 },
			xAxis: {
				type: 'category',
				data: ['1', '2', '3', '4'],
				axisLabel: { fontFamily: 'Tahoma', fontWeight: 700, color: '#475569' },
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
					name: 'ตรวจตา',
					type: 'line',
					data: eyeValues,
					smooth: true,
					connectNulls: false,
					symbolSize: 9,
					lineStyle: { width: 4, color: '#10B981' },
					itemStyle: { color: '#10B981' }
				},
				{
					name: 'ตรวจช่องปากและฟัน',
					type: 'line',
					data: oralValues,
					smooth: true,
					connectNulls: false,
					symbolSize: 9,
					lineStyle: { width: 4, color: '#F59E0B' },
					itemStyle: { color: '#F59E0B' }
				},
				{
					name: 'ตรวจเท้า',
					type: 'line',
					data: footValues,
					smooth: true,
					connectNulls: false,
					symbolSize: 9,
					lineStyle: { width: 4, color: '#8B5CF6' },
					itemStyle: { color: '#8B5CF6' }
				}
			].filter((_, index) => index === indicatorNo - 13) as EChartsOption['series']
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
	<div
		role="img"
		aria-label={`กราฟแนวโน้มรายไตรมาสของ${domainLabel} ปีงบประมาณ ${year}`}
		class="h-[230px] w-full min-w-0"
		bind:this={chartEl}
	></div>
	<p class="text-center text-xs font-medium text-slate-500">ไตรมาส</p>
	<dl class="mt-3 grid grid-cols-4 gap-1 border-t border-slate-100 pt-3 text-center text-xs">
		{#each selectedValues as value, index (index)}
			<div>
				<dt class="text-slate-500">ไตรมาส {index + 1}</dt>
				<dd class="mt-1 font-bold text-slate-700">
					{value === null
						? 'ไม่มีข้อมูล'
						: value.toLocaleString('th-TH', { maximumFractionDigits: 2 }) + '%'}
				</dd>
			</div>
		{/each}
	</dl>
{:else}
	<div
		class="grid h-[230px] place-items-center rounded-3xl border border-dashed border-slate-200 p-4 text-center"
	>
		<p role="status" class="font-bold text-slate-500">ยังไม่มีข้อมูลรายไตรมาสสำหรับปีงบประมาณนี้</p>
	</div>
{/if}
