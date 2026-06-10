<script lang="ts">
	import { onMount } from 'svelte';
	import * as echarts from 'echarts';
	import type { ECharts, EChartsOption } from 'echarts';
	import type { NcdIndicator } from '$lib/data';

	let {
		rows = [],
		selectedYear
	}: {
		rows?: NcdIndicator[];
		selectedYear: number;
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

	let monthlyRows = $derived(
		rows
			.filter((row) => row.fiscal_year_be === selectedYear)
			.filter((row) => row.period_type === 'เดือน')
			.filter((row) => visibleIndicatorNos.includes(row.indicator_no))
			.filter((row) => row.actual_percent !== null)
			.sort((a, b) => {
				if (a.period_order !== b.period_order) return a.period_order - b.period_order;
				return a.indicator_no - b.indicator_no;
			})
	);

	let periods = $derived(
		[
			...new Map(
				monthlyRows.map((row) => [
					row.period_order,
					{
						order: row.period_order,
						label: row.period_label
					}
				])
			).values()
		].sort((a, b) => a.order - b.order)
	);

	let indicatorGroups = $derived(
		visibleIndicatorNos
			.map((indicatorNo) => monthlyRows.find((row) => row.indicator_no === indicatorNo))
			.filter(Boolean) as NcdIndicator[]
	);

	let hasData = $derived(monthlyRows.length > 0);

	function buildOptions(): EChartsOption {
		const labels = periods.map((period) => period.label);

		const colors: Record<number, string> = {
			13: '#10B981',
			14: '#F59E0B',
			15: '#8B5CF6'
		};

		const series = indicatorGroups.map((indicator) => {
			const data = periods.map((period) => {
				const found = monthlyRows.find(
					(row) => row.period_order === period.order && row.indicator_no === indicator.indicator_no
				);

				return found?.actual_percent ?? null;
			});

			return {
				name: shortName(indicator),
				type: 'line',
				smooth: true,
				symbolSize: 8,
				connectNulls: true,
				data,
				lineStyle: {
					width: 4,
					color: colors[indicator.indicator_no] ?? '#64748B'
				},
				itemStyle: {
					color: colors[indicator.indicator_no] ?? '#64748B'
				},
				emphasis: {
					focus: 'series'
				}
			};
		});

		return {
			backgroundColor: 'transparent',

			tooltip: {
				trigger: 'axis',
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
				itemWidth: 14,
				itemHeight: 10,
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
				bottom: 44
			},

			xAxis: {
				type: 'category',
				data: labels,
				boundaryGap: false,
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

			series
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
		<p class="font-bold text-slate-400">ไม่มีข้อมูลแนวโน้มรายเดือน</p>
	</div>
{/if}
