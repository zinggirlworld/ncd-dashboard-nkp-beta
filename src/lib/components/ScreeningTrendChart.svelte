<script lang="ts">
	import * as echarts from 'echarts';
	import type { ECharts, EChartsOption } from 'echarts';
	import type { NcdIndicator } from '$lib/data';

	let {
		rows = [],
		year
	}: {
		rows?: NcdIndicator[];
		year: number;
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
			return row?.numerator ?? null;
		});
	}

	let eyeValues = $derived(valuesFor(13));
	let oralValues = $derived(valuesFor(14));
	let footValues = $derived(valuesFor(15));
	let hasData = $derived(
		[...eyeValues, ...oralValues, ...footValues].some((value) => value !== null)
	);

	function buildOptions(): EChartsOption {
		const makeSeries = (
			name: string,
			data: Array<number | null>,
			color: string
		): NonNullable<EChartsOption['series']>[number] => ({
			name,
			type: 'line',
			data,
			smooth: true,
			connectNulls: false,
			symbol: 'circle',
			symbolSize: 10,
			lineStyle: { width: 4, color },
			itemStyle: { color },
			label: {
				show: true,
				position: 'top',
				distance: 8,
				formatter: (params) =>
					params.value === null || params.value === undefined
						? ''
						: Number(params.value).toLocaleString('th-TH'),
				fontFamily: 'Tahoma',
				fontWeight: 800,
				color
			}
		});

		return {
			backgroundColor: 'transparent',
			tooltip: {
				trigger: 'axis',
				borderColor: '#E2E8F0',
				borderWidth: 1,
				backgroundColor: 'rgba(255,255,255,0.98)',
				textStyle: { fontFamily: 'Tahoma', color: '#334155', fontWeight: 700 },
				valueFormatter: (value) =>
					value === null || value === undefined
						? '-'
						: `${Number(value).toLocaleString('th-TH')} HN`
			},
			legend: {
				top: 4,
				left: 'center',
				itemWidth: 18,
				itemHeight: 10,
				textStyle: { fontFamily: 'Tahoma', fontWeight: 700, color: '#475569' }
			},
			grid: { left: 58, right: 30, top: 72, bottom: 48, containLabel: true },
			xAxis: {
				type: 'category',
				boundaryGap: false,
				data: ['Q1', 'Q2', 'Q3', 'Q4'],
				axisLabel: { fontFamily: 'Tahoma', fontWeight: 700, color: '#475569' },
				axisLine: { lineStyle: { color: '#CBD5E1' } }
			},
			yAxis: {
				type: 'value',
				min: 0,
				name: 'HN',
				nameTextStyle: { fontFamily: 'Tahoma', fontWeight: 700, color: '#64748B' },
				axisLabel: {
					fontFamily: 'Tahoma',
					fontWeight: 700,
					color: '#64748B'
				},
				splitLine: { lineStyle: { color: '#E2E8F0', type: 'dashed' } }
			},
			series: [
				makeSeries('ตรวจจอประสาทตา', eyeValues, '#10B981'),
				makeSeries('ตรวจช่องปากและฟัน', oralValues, '#F59E0B'),
				makeSeries('ตรวจเท้า', footValues, '#8B5CF6')
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
	<div
		role="img"
		aria-label={`กราฟเปรียบเทียบแนวโน้มจำนวน HN รายไตรมาสของการตรวจจอประสาทตา ตรวจสุขภาพช่องปากและฟัน และตรวจเท้า ปีงบประมาณ ${year}`}
		class="h-[360px] w-full min-w-0 sm:h-[400px]"
		bind:this={chartEl}
	></div>
{:else}
	<div
		class="grid h-[300px] place-items-center rounded-3xl border border-dashed border-slate-200 p-4 text-center"
	>
		<p role="status" class="font-bold text-slate-500">ยังไม่มีข้อมูลรายไตรมาสสำหรับปีงบประมาณนี้</p>
	</div>
{/if}
