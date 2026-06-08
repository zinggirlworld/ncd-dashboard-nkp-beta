<script lang="ts">
	import { onMount } from 'svelte';
	import * as echarts from 'echarts';
	import type { ECharts, EChartsOption } from 'echarts';
	import type { NcdIndicator } from '$lib/data';

	let {
		rows = [],
		selectedYear = 2569
	}: {
		rows?: NcdIndicator[];
		selectedYear?: number;
	} = $props();

	let chartEl: HTMLDivElement;
	let chart: ECharts | null = null;

	const selectedIndicatorNos = [1, 13, 14, 15];

	let monthlyRows = $derived(
		rows
			.filter((row) => row.fiscal_year_be === selectedYear)
			.filter((row) => row.period_type === 'เดือน')
			.filter((row) => selectedIndicatorNos.includes(row.indicator_no))
			.filter((row) => row.actual_percent !== null && row.actual_percent !== undefined)
			.sort((a, b) => {
				if (a.period_order !== b.period_order) return a.period_order - b.period_order;
				return a.indicator_no - b.indicator_no;
			})
	);

	let hasData = $derived(monthlyRows.length > 0);

	let months = $derived(
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

	let indicators = $derived(
		[
			...new Map(
				monthlyRows.map((row) => [
					row.indicator_no,
					{
						no: row.indicator_no,
						name: shortName(row),
						target: row.target_value ?? 0
					}
				])
			).values()
		].sort((a, b) => a.no - b.no)
	);

	function shortName(row: NcdIndicator): string {
		if (row.indicator_no === 1) return 'ตรวจ HbA1c';
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
		const monthLabels = months.map((month) => month.label);

		const colorMap: Record<number, string> = {
			1: '#0EA5E9',
			13: '#10B981',
			14: '#F59E0B',
			15: '#8B5CF6'
		};

		const series = indicators.map((indicator) => {
			const data = months.map((month) => {
				const found = monthlyRows.find(
					(row) => row.indicator_no === indicator.no && row.period_order === month.order
				);

				return found?.actual_percent ?? null;
			});

			return {
				name: indicator.name,
				type: 'line',
				data,
				smooth: true,
				connectNulls: false,
				symbol: 'circle',
				symbolSize: 8,
				lineStyle: {
					width: 4,
					color: colorMap[indicator.no] ?? '#64748B'
				},
				itemStyle: {
					color: colorMap[indicator.no] ?? '#64748B',
					borderColor: '#ffffff',
					borderWidth: 2
				},
				areaStyle: {
					opacity: 0.06,
					color: colorMap[indicator.no] ?? '#64748B'
				},
				emphasis: {
					focus: 'series',
					lineStyle: {
						width: 5
					}
				}
			};
		});

		return {
			backgroundColor: 'transparent',

			tooltip: {
				trigger: 'axis',
				axisPointer: {
					type: 'line',
					lineStyle: {
						color: '#94A3B8',
						type: 'dashed',
						width: 2
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

					if (items.length === 0) return '';

					const first = items[0] as {
						axisValue?: string;
					};

					let html = `
						<div style="min-width: 220px;">
							<div style="font-size: 14px; color: #0F172A; font-weight: 900; margin-bottom: 10px;">
								${first.axisValue ?? ''}
							</div>
					`;

					for (const item of items as Array<{
						seriesName: string;
						value: number | null;
						color: string;
					}>) {
						html += `
							<div style="display: flex; justify-content: space-between; gap: 16px; margin-bottom: 6px;">
								<span style="display: flex; align-items: center; gap: 7px;">
									<span style="
										display: inline-block;
										width: 9px;
										height: 9px;
										border-radius: 999px;
										background: ${item.color};
									"></span>
									${item.seriesName}
								</span>
								<strong>${item.value === null ? '-' : formatPercent(Number(item.value))}</strong>
							</div>
						`;
					}

					html += '</div>';
					return html;
				}
			},

			legend: {
				top: 0,
				right: 0,
				itemWidth: 16,
				itemHeight: 10,
				textStyle: {
					fontFamily: 'Tahoma',
					fontWeight: 700,
					color: '#334155'
				}
			},

			grid: {
				left: 52,
				right: 28,
				top: 58,
				bottom: 50
			},

			xAxis: {
				type: 'category',
				boundaryGap: false,
				data: monthLabels,
				axisLabel: {
					fontFamily: 'Tahoma',
					fontWeight: 700,
					color: '#475569',
					margin: 14
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
	<div
		class="grid h-[300px] w-full place-items-center rounded-3xl border border-dashed border-emerald-200 bg-emerald-50/50"
	>
		<div class="text-center">
			<p class="text-base font-black text-emerald-700">ไม่มีข้อมูลรายเดือนสำหรับแสดงกราฟ</p>
			<p class="mt-1 text-sm font-semibold text-slate-500">
				กรุณาเลือกปีงบประมาณที่มีข้อมูลรายเดือน
			</p>
		</div>
	</div>
{/if}
