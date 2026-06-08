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

	let chartEl: HTMLDivElement;
	let chart: ECharts | null = null;

	let chartRows = $derived(
		rows
			.filter((row) => row.gap_from_target !== null && row.gap_from_target !== undefined)
			.sort((a, b) => (a.gap_from_target ?? 0) - (b.gap_from_target ?? 0))
	);

	let hasData = $derived(chartRows.length > 0);

	function shortName(row: NcdIndicator): string {
		if (row.indicator_no === 1) return 'ตรวจ HbA1c';
		if (row.indicator_no === 2) return 'HbA1c < 7';
		if (row.indicator_no === 13) return 'ตรวจตา';
		if (row.indicator_no === 14) return 'ตรวจช่องปาก';
		if (row.indicator_no === 15) return 'ตรวจเท้า';

		return `ตัวชี้วัด ${row.indicator_no}`;
	}

	function formatNumber(value: number | null | undefined): string {
		if (value === null || value === undefined) return '-';

		return value.toLocaleString('th-TH', {
			minimumFractionDigits: 2,
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

	function buildOptions(): EChartsOption {
		const labels = chartRows.map(shortName);
		const gapData = chartRows.map((row) => Number(row.gap_from_target ?? 0));

		const minGap = Math.min(...gapData, 0);
		const maxGap = Math.max(...gapData, 0);
		const padding = Math.max(Math.abs(minGap), Math.abs(maxGap), 10) * 0.18;

		return {
			backgroundColor: 'transparent',

			tooltip: {
				trigger: 'axis',
				axisPointer: {
					type: 'shadow',
					shadowStyle: {
						color: 'rgba(244, 63, 94, 0.06)'
					}
				},
				borderColor: '#FFE4E6',
				borderWidth: 1,
				backgroundColor: 'rgba(255, 255, 255, 0.96)',
				textStyle: {
					fontFamily: 'Tahoma',
					color: '#334155',
					fontWeight: 700
				},
				formatter: (params) => {
					const items = Array.isArray(params) ? params : [params];
					const first = items[0] as { dataIndex: number };
					const row = chartRows[first.dataIndex];

					if (!row) return '';

					const gap = Number(row.gap_from_target ?? 0);
					const gapColor = gap >= 0 ? '#059669' : '#E11D48';

					return `
						<div style="min-width: 240px;">
							<div style="font-size: 13px; color: #0F766E; margin-bottom: 6px;">
								ตัวชี้วัดที่ ${row.indicator_no}
							</div>
							<div style="font-size: 14px; color: #0F172A; margin-bottom: 10px; line-height: 1.4;">
								${row.indicator_name}
							</div>
							<div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
								<span>ผลงานจริง</span>
								<strong>${formatPercent(row.actual_percent)}</strong>
							</div>
							<div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
								<span>เป้าหมาย</span>
								<strong>${row.target_text}</strong>
							</div>
							<div style="display: flex; justify-content: space-between;">
								<span>Gap จากเป้าหมาย</span>
								<strong style="color: ${gapColor};">${formatNumber(gap)}</strong>
							</div>
						</div>
					`;
				}
			},

			grid: {
				left: 108,
				right: 36,
				top: 18,
				bottom: 32
			},

			xAxis: {
				type: 'value',
				min: Math.floor(minGap - padding),
				max: Math.ceil(maxGap + padding),
				axisLabel: {
					fontFamily: 'Tahoma',
					fontWeight: 700,
					color: '#64748B'
				},
				axisLine: {
					show: false
				},
				axisTick: {
					show: false
				},
				splitLine: {
					lineStyle: {
						color: '#E2E8F0',
						type: 'dashed'
					}
				}
			},

			yAxis: {
				type: 'category',
				data: labels,
				inverse: true,
				axisLabel: {
					fontFamily: 'Tahoma',
					fontWeight: 800,
					color: '#334155'
				},
				axisLine: {
					show: false
				},
				axisTick: {
					show: false
				}
			},

			series: [
				{
					name: 'Gap',
					type: 'bar',
					data: gapData,
					barWidth: 18,
					barMaxWidth: 22,
					itemStyle: {
						color: (params) => {
							const value = Number(params.value);
							return value >= 0 ? '#10B981' : '#F43F5E';
						},
						borderRadius: [8, 8, 8, 8]
					},
					label: {
						show: true,
						position: (params) => {
							const value = Number(params.value);
							return value >= 0 ? 'right' : 'left';
						},
						formatter: (params) => formatNumber(Number(params.value)),
						fontFamily: 'Tahoma',
						fontWeight: 900,
						color: '#334155'
					},
					markLine: {
						symbol: 'none',
						lineStyle: {
							color: '#94A3B8',
							type: 'dashed',
							width: 2
						},
						label: {
							show: false
						},
						data: [
							{
								xAxis: 0
							}
						]
					},
					emphasis: {
						itemStyle: {
							shadowBlur: 14,
							shadowColor: 'rgba(244, 63, 94, 0.18)'
						}
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
	<div class="h-[320px] w-full" bind:this={chartEl}></div>
{:else}
	<div
		class="grid h-[260px] w-full place-items-center rounded-3xl border border-dashed border-rose-200 bg-rose-50/40"
	>
		<div class="text-center">
			<p class="text-base font-black text-rose-700">ไม่มีข้อมูล Gap สำหรับแสดงกราฟ</p>
			<p class="mt-1 text-sm font-semibold text-slate-500">
				กรุณาเลือกปีงบประมาณ ช่วงเวลา หรืองวดข้อมูลใหม่
			</p>
		</div>
	</div>
{/if}
