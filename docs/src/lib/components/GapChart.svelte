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
			.filter((row) => row.gap_from_target !== null)
			.filter((row) => (row.gap_from_target ?? 0) < 0)
			.sort((a, b) => (a.gap_from_target ?? 0) - (b.gap_from_target ?? 0))
	);

	let hasData = $derived(chartRows.length > 0);

	function buildOptions(): EChartsOption {
		const labels = chartRows.map(shortName);
		const gapData = chartRows.map((row) => Number((row.gap_from_target ?? 0).toFixed(2)));

		const minGap = Math.min(...gapData, -10);
		const axisMin = Math.floor((minGap - 5) / 10) * 10;

		return {
			backgroundColor: 'transparent',

			tooltip: {
				trigger: 'axis',
				axisPointer: {
					type: 'shadow'
				},
				valueFormatter: (value) => `${Number(value).toFixed(2)}`,
				borderColor: '#FECACA',
				borderWidth: 1,
				backgroundColor: 'rgba(255, 255, 255, 0.96)',
				textStyle: {
					fontFamily: 'Tahoma',
					color: '#334155',
					fontWeight: 700
				}
			},

			grid: {
				left: 95,
				right: 28,
				top: 18,
				bottom: 36
			},

			xAxis: {
				type: 'value',
				min: axisMin,
				max: 0,
				axisLabel: {
					fontFamily: 'Tahoma',
					fontWeight: 700,
					color: '#64748B'
				},
				splitLine: {
					lineStyle: {
						color: '#E2E8F0',
						type: 'dashed'
					}
				},
				axisLine: {
					lineStyle: {
						color: '#CBD5E1'
					}
				}
			},

			yAxis: {
				type: 'category',
				data: labels,
				axisLabel: {
					fontFamily: 'Tahoma',
					fontWeight: 800,
					color: '#334155'
				},
				axisTick: {
					show: false
				},
				axisLine: {
					show: false
				}
			},

			series: [
				{
					name: 'Gap จากเป้าหมาย',
					type: 'bar',
					data: gapData,
					barWidth: 24,
					itemStyle: {
						color: '#F43F5E',
						borderRadius: [0, 999, 999, 0]
					},
					label: {
						show: true,
						position: 'insideRight',
						formatter: (params) => `${Number(params.value).toFixed(2)}`,
						fontFamily: 'Tahoma',
						fontWeight: 900,
						color: '#FFFFFF'
					},
					markLine: {
						silent: true,
						symbol: 'none',
						lineStyle: {
							color: '#94A3B8',
							type: 'dashed',
							width: 2
						},
						label: {
							show: false
						},
						data: [{ xAxis: 0 }]
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
		if (!hasData) {
			chart?.clear();
			return;
		}

		if (!chart && chartEl) {
			chart = echarts.init(chartEl);
		}

		renderChart();
	});
</script>

{#if hasData}
	<div class="h-[300px] w-full" bind:this={chartEl}></div>
{:else}
	<div
		class="grid h-[240px] place-items-center rounded-3xl border border-emerald-100 bg-emerald-50/60"
	>
		<div class="text-center">
			<p class="text-base font-black text-emerald-700">ไม่มีรายการคัดกรองที่ต่ำกว่าเป้าหมาย</p>
			<p class="mt-1 text-sm font-semibold text-slate-500">
				ตรวจตา ตรวจช่องปาก และตรวจเท้า อยู่ในเกณฑ์เป้าหมายในช่วงเวลานี้
			</p>
		</div>
	</div>
{/if}
