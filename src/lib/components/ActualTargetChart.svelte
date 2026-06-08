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
			.filter((row) => row.actual_percent !== null && row.actual_percent !== undefined)
			.sort((a, b) => a.indicator_no - b.indicator_no)
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

	function formatPercent(value: number | null | undefined): string {
		if (value === null || value === undefined) return '-';

		return `${value.toLocaleString('th-TH', {
			minimumFractionDigits: 2,
			maximumFractionDigits: 2
		})}%`;
	}

	function buildOptions(): EChartsOption {
		const labels = chartRows.map(shortName);
		const actualData = chartRows.map((row) => Number(row.actual_percent ?? 0));
		const targetData = chartRows.map((row) => Number(row.target_value ?? 0));

		return {
			backgroundColor: 'transparent',

			tooltip: {
				trigger: 'axis',
				axisPointer: {
					type: 'shadow',
					shadowStyle: {
						color: 'rgba(15, 118, 110, 0.06)'
					}
				},
				borderColor: '#D1FAE5',
				borderWidth: 1,
				backgroundColor: 'rgba(255, 255, 255, 0.96)',
				textStyle: {
					fontFamily: 'Tahoma',
					color: '#334155',
					fontWeight: 700
				},
				formatter: (params) => {
					const items = Array.isArray(params) ? params : [params];
					const first = items[0] as { dataIndex: number; axisValue?: string };
					const row = chartRows[first.dataIndex];

					if (!row) return '';

					const actual = Number(row.actual_percent ?? 0);
					const target = Number(row.target_value ?? 0);
					const gap = actual - target;
					const statusColor = actual >= target ? '#059669' : '#E11D48';

					return `
						<div style="min-width: 220px;">
							<div style="font-size: 13px; color: #0F766E; margin-bottom: 6px;">
								ตัวชี้วัดที่ ${row.indicator_no}
							</div>
							<div style="font-size: 14px; color: #0F172A; margin-bottom: 10px; line-height: 1.4;">
								${row.indicator_name}
							</div>
							<div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
								<span>ผลงานจริง</span>
								<strong style="color: ${statusColor};">${formatPercent(actual)}</strong>
							</div>
							<div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
								<span>เป้าหมาย</span>
								<strong>${formatPercent(target)}</strong>
							</div>
							<div style="display: flex; justify-content: space-between;">
								<span>Gap</span>
								<strong style="color: ${gap >= 0 ? '#059669' : '#E11D48'};">
									${gap.toLocaleString('th-TH', {
										minimumFractionDigits: 2,
										maximumFractionDigits: 2
									})}
								</strong>
							</div>
						</div>
					`;
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
				top: 58,
				bottom: 58
			},

			xAxis: {
				type: 'category',
				data: labels,
				axisLabel: {
					fontFamily: 'Tahoma',
					fontWeight: 700,
					color: '#475569',
					interval: 0,
					margin: 16
				},
				axisLine: {
					lineStyle: {
						color: '#CBD5E1'
					}
				},
				axisTick: {
					show: false
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

			series: [
				{
					name: 'ผลงานจริง',
					type: 'bar',
					data: actualData,
					barWidth: 34,
					barMaxWidth: 42,
					itemStyle: {
						color: (params) => {
							const value = Number(params.value);
							const target = targetData[params.dataIndex];

							return value >= target ? '#10B981' : '#F43F5E';
						},
						borderRadius: [10, 10, 0, 0]
					},
					label: {
						show: true,
						position: 'top',
						formatter: (params) => `${Number(params.value).toFixed(1)}%`,
						fontFamily: 'Tahoma',
						fontWeight: 800,
						color: '#0F172A'
					},
					emphasis: {
						itemStyle: {
							shadowBlur: 14,
							shadowColor: 'rgba(15, 118, 110, 0.18)'
						}
					}
				},
				{
					name: 'เป้าหมาย',
					type: 'line',
					data: targetData,
					smooth: true,
					symbol: 'circle',
					symbolSize: 9,
					lineStyle: {
						width: 4,
						color: '#64748B',
						type: 'dashed'
					},
					itemStyle: {
						color: '#64748B',
						borderColor: '#ffffff',
						borderWidth: 2
					},
					label: {
						show: false
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
	<div class="h-[380px] w-full" bind:this={chartEl}></div>
{:else}
	<div
		class="grid h-[300px] w-full place-items-center rounded-3xl border border-dashed border-emerald-200 bg-emerald-50/50"
	>
		<div class="text-center">
			<p class="text-base font-black text-emerald-700">ไม่มีข้อมูลสำหรับแสดงกราฟ</p>
			<p class="mt-1 text-sm font-semibold text-slate-500">
				กรุณาเลือกปีงบประมาณ ช่วงเวลา หรืองวดข้อมูลใหม่
			</p>
		</div>
	</div>
{/if}
