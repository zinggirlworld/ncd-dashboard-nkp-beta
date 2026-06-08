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

	let passedCount = $derived(rows.filter((row) => row.status === 'ผ่าน').length);
	let failedCount = $derived(rows.filter((row) => row.status === 'ไม่ผ่าน').length);
	let otherCount = $derived(
		rows.filter((row) => row.status !== 'ผ่าน' && row.status !== 'ไม่ผ่าน').length
	);

	let totalCount = $derived(rows.length);
	let passRate = $derived(totalCount > 0 ? (passedCount * 100) / totalCount : 0);
	let hasData = $derived(totalCount > 0);

	function formatNumber(value: number): string {
		return value.toLocaleString('th-TH');
	}

	function formatPercent(value: number): string {
		return `${value.toLocaleString('th-TH', {
			minimumFractionDigits: 2,
			maximumFractionDigits: 2
		})}%`;
	}

	function buildOptions(): EChartsOption {
		const chartData = [
			{
				value: passedCount,
				name: 'ผ่าน',
				itemStyle: {
					color: '#10B981'
				}
			},
			{
				value: failedCount,
				name: 'ไม่ผ่าน',
				itemStyle: {
					color: '#F43F5E'
				}
			}
		];

		if (otherCount > 0) {
			chartData.push({
				value: otherCount,
				name: 'อื่น ๆ',
				itemStyle: {
					color: '#94A3B8'
				}
			});
		}

		return {
			backgroundColor: 'transparent',

			tooltip: {
				trigger: 'item',
				borderColor: '#D1FAE5',
				borderWidth: 1,
				backgroundColor: 'rgba(255, 255, 255, 0.96)',
				textStyle: {
					fontFamily: 'Tahoma',
					color: '#334155',
					fontWeight: 700
				},
				formatter: (params) => {
					const item = params as {
						name: string;
						value: number;
						percent: number;
						color: string;
					};

					return `
						<div style="min-width: 170px;">
							<div style="display: flex; align-items: center; gap: 8px; margin-bottom: 8px;">
								<span style="
									display: inline-block;
									width: 10px;
									height: 10px;
									border-radius: 999px;
									background: ${item.color};
								"></span>
								<strong style="font-size: 14px; color: #0F172A;">
									${item.name}
								</strong>
							</div>

							<div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
								<span>จำนวน</span>
								<strong>${formatNumber(Number(item.value))} รายการ</strong>
							</div>

							<div style="display: flex; justify-content: space-between;">
								<span>สัดส่วน</span>
								<strong>${formatPercent(Number(item.percent))}</strong>
							</div>
						</div>
					`;
				}
			},

			legend: {
				bottom: 0,
				left: 'center',
				itemWidth: 12,
				itemHeight: 10,
				textStyle: {
					fontFamily: 'Tahoma',
					fontWeight: 700,
					color: '#334155'
				}
			},

			graphic: [
				{
					type: 'text',
					left: 'center',
					top: '38%',
					style: {
						text: 'ผ่าน',
						fill: '#64748B',
						fontFamily: 'Tahoma',
						fontWeight: 700,
						fontSize: 13,
						textAlign: 'center'
					}
				},
				{
					type: 'text',
					left: 'center',
					top: '46%',
					style: {
						text: formatPercent(passRate),
						fill: passRate >= 70 ? '#059669' : '#E11D48',
						fontFamily: 'Tahoma',
						fontWeight: 900,
						fontSize: 26,
						textAlign: 'center'
					}
				},
				{
					type: 'text',
					left: 'center',
					top: '58%',
					style: {
						text: `${formatNumber(passedCount)} / ${formatNumber(totalCount)} รายการ`,
						fill: '#64748B',
						fontFamily: 'Tahoma',
						fontWeight: 700,
						fontSize: 12,
						textAlign: 'center'
					}
				}
			],

			series: [
				{
					name: 'สถานะตัวชี้วัด',
					type: 'pie',
					radius: ['58%', '78%'],
					center: ['50%', '48%'],
					avoidLabelOverlap: true,
					silent: false,
					itemStyle: {
						borderRadius: 12,
						borderColor: '#FFFFFF',
						borderWidth: 5
					},
					label: {
						show: false
					},
					labelLine: {
						show: false
					},
					emphasis: {
						scale: true,
						scaleSize: 6,
						itemStyle: {
							shadowBlur: 16,
							shadowColor: 'rgba(15, 23, 42, 0.12)'
						}
					},
					data: chartData
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
	<div class="h-[300px] w-full" bind:this={chartEl}></div>
{:else}
	<div
		class="grid h-[260px] w-full place-items-center rounded-3xl border border-dashed border-emerald-200 bg-emerald-50/50"
	>
		<div class="text-center">
			<p class="text-base font-black text-emerald-700">ไม่มีข้อมูลสถานะสำหรับแสดงกราฟ</p>
			<p class="mt-1 text-sm font-semibold text-slate-500">
				กรุณาเลือกปีงบประมาณ ช่วงเวลา หรืองวดข้อมูลใหม่
			</p>
		</div>
	</div>
{/if}
