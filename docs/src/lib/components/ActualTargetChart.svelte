<script lang="ts">
	import { onMount } from 'svelte';
	import * as echarts from 'echarts';
	import type { ECharts, EChartsOption } from 'echarts';
	import type { NcdIndicator } from '$lib/data';

	let {
		rows = []
	}: {
		rows?: NcdIndicator[];
	} = $props();

	let chartEl = $state<HTMLDivElement | null>(null);
	let chart: ECharts | null = null;

	const visibleIndicatorNos = [13, 14, 15];

	function shortName(row: NcdIndicator): string {
		if (row.indicator_no === 13) return 'ตรวจตา';
		if (row.indicator_no === 14) return 'ตรวจช่องปาก';
		if (row.indicator_no === 15) return 'ตรวจเท้า';

		return `ตัวชี้วัด ${row.indicator_no}`;
	}

	let chartRows = $derived(
		rows
			.filter((row) => visibleIndicatorNos.includes(row.indicator_no))
			.filter((row) => row.actual_percent !== null)
			.sort((a, b) => a.indicator_no - b.indicator_no)
	);

	let hasData = $derived(chartRows.length > 0);

	function buildOptions(): EChartsOption {
		const labels = chartRows.map(shortName);
		const actualData = chartRows.map((row) => row.actual_percent ?? 0);
		const targetData = chartRows.map((row) => row.target_value ?? 0);

		return {
			backgroundColor: 'transparent',

			tooltip: {
				trigger: 'axis',
				axisPointer: {
					type: 'shadow'
				},
				valueFormatter: (value) => `${Number(value).toFixed(2)}%`,
				borderColor: '#D1FAE5',
				borderWidth: 1,
				backgroundColor: 'rgba(255, 255, 255, 0.96)',
				textStyle: {
					fontFamily: 'Tahoma',
					color: '#334155',
					fontWeight: 700
				}
			},

			legend: {
				top: 0,
				right: 0,
				textStyle: {
					fontFamily: 'Tahoma',
					fontWeight: 700,
					color: '#334155'
				}
			},

			grid: {
				left: 52,
				right: 24,
				top: 60,
				bottom: 48
			},

			xAxis: {
				type: 'category',
				data: labels,
				axisLabel: {
					fontFamily: 'Tahoma',
					fontWeight: 700,
					color: '#475569',
					interval: 0
				},
				axisLine: {
					lineStyle: {
						color: '#CBD5E1'
					}
				}
			},

			yAxis: {
				type: 'value',
				min: 0,
				max: 100,
				axisLabel: {
					formatter: '{value}%',
					fontFamily: 'Tahoma',
					fontWeight: 700,
					color: '#475569'
				},
				splitLine: {
					lineStyle: {
						color: '#E2E8F0',
						type: 'dashed'
					}
				}
			},

			series: [
				{
					name: 'ผลงานจริง',
					type: 'bar',
					data: actualData,
					barWidth: 42,
					itemStyle: {
						color: (params) => {
							const value = Number(params.value);
							const target = targetData[params.dataIndex];

							return value >= target ? '#10B981' : '#F43F5E';
						},
						borderRadius: [14, 14, 0, 0]
					},
					label: {
						show: true,
						position: 'top',
						formatter: (params) => `${Number(params.value).toFixed(1)}%`,
						fontFamily: 'Tahoma',
						fontWeight: 800,
						color: '#0F172A'
					}
				},
				{
					name: 'เป้าหมาย',
					type: 'line',
					data: targetData,
					smooth: true,
					symbolSize: 9,
					lineStyle: {
						width: 4,
						color: '#64748B',
						type: 'dashed'
					},
					itemStyle: {
						color: '#64748B'
					}
				}
			]
		};
	}

	function renderChart() {
		if (!chart || !hasData) return;
		chart.setOption(buildOptions(), true);
	}

	onMount(() => {
		if (!chartEl || !hasData) return;

		chart = echarts.init(chartEl);
		renderChart();

		const handleResize = () => chart?.resize();
		window.addEventListener('resize', handleResize);

		return () => {
			window.removeEventListener('resize', handleResize);
			chart?.dispose();
			chart = null;
		};
	});

	$effect(() => {
		if (!hasData) return;

		if (!chart && chartEl) {
			chart = echarts.init(chartEl);
		}

		renderChart();
	});
</script>

{#if hasData}
	<div class="h-[360px] w-full" bind:this={chartEl}></div>
{:else}
	<div class="grid h-[280px] place-items-center rounded-3xl border border-dashed border-slate-200">
		<p class="font-bold text-slate-400">ไม่มีข้อมูลผลงานเทียบเป้าหมาย</p>
	</div>
{/if}
