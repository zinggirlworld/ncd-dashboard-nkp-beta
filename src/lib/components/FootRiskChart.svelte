<script lang="ts">
	import { onMount } from 'svelte';
	import * as echarts from 'echarts';
	import type { ECharts, EChartsOption } from 'echarts';
	import type { FootRiskRow } from '$lib/footRiskData';

	let {
		rows = []
	}: {
		rows?: FootRiskRow[];
	} = $props();

	let chartEl: HTMLDivElement;
	let chart: ECharts | null = null;

	let chartRows = $derived(
		rows.filter((row) => row.total_hn > 0).sort((a, b) => a.risk_order - b.risk_order)
	);

	let hasData = $derived(chartRows.length > 0);

	let totalHn = $derived(chartRows.reduce((sum, row) => sum + row.total_hn, 0));

	let highRiskHn = $derived(
		chartRows
			.filter((row) => row.risk_code === 'Z0282' || row.risk_code === 'Z0283')
			.reduce((sum, row) => sum + row.total_hn, 0)
	);

	let highRiskPercent = $derived(totalHn > 0 ? (highRiskHn * 100) / totalHn : 0);

	function riskColor(code: string): string {
		if (code === 'Z0280') return '#10B981';
		if (code === 'Z0281') return '#F59E0B';
		if (code === 'Z0282') return '#F97316';
		if (code === 'Z0283') return '#EF4444';

		return '#94A3B8';
	}

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
		const data = chartRows.map((row) => ({
			name: row.risk_name,
			value: row.total_hn,
			itemStyle: {
				color: riskColor(row.risk_code)
			}
		}));

		return {
			backgroundColor: 'transparent',

			tooltip: {
				trigger: 'item',
				borderColor: '#FED7AA',
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
						<div style="min-width: 180px;">
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
								<strong>${formatNumber(Number(item.value))} HN</strong>
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
						text: 'เสี่ยงสูงขึ้นไป',
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
						text: formatPercent(highRiskPercent),
						fill: highRiskPercent >= 10 ? '#E11D48' : '#059669',
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
						text: `${formatNumber(highRiskHn)} / ${formatNumber(totalHn)} HN`,
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
					name: 'ความเสี่ยงเท้า',
					type: 'pie',
					radius: ['58%', '78%'],
					center: ['50%', '48%'],
					avoidLabelOverlap: true,
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
					data
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
	<div class="grid grid-cols-1 gap-5 xl:grid-cols-[0.9fr_1.1fr]">
		<div class="h-[320px] w-full" bind:this={chartEl}></div>

		<div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
			{#each chartRows as row}
				<div class="rounded-3xl border border-slate-100 bg-slate-50 p-4">
					<div class="flex items-start justify-between gap-3">
						<div>
							<p class="text-xs font-black text-slate-400">{row.risk_code}</p>
							<h3 class="mt-1 text-lg font-black text-slate-800">{row.risk_name}</h3>
						</div>

						<div
							class="h-4 w-4 rounded-full"
							style={`background-color: ${riskColor(row.risk_code)}`}
						></div>
					</div>

					<p class="mt-4 text-4xl font-black text-slate-800">
						{formatNumber(row.total_hn)}
					</p>
					<p class="mt-1 text-sm font-semibold text-slate-500">HN</p>
				</div>
			{/each}

			<div class="rounded-3xl border border-rose-100 bg-rose-50 p-4 sm:col-span-2">
				<p class="text-sm font-black text-rose-700">กลุ่มที่ควรติดตามใกล้ชิด</p>
				<p class="mt-2 text-4xl font-black text-rose-600">
					{formatNumber(highRiskHn)} HN
				</p>
				<p class="mt-1 text-sm font-semibold text-rose-600">
					เสี่ยงสูง + เสี่ยงสูงมาก คิดเป็น {formatPercent(highRiskPercent)}
				</p>
			</div>
		</div>
	</div>
{:else}
	<div
		class="grid h-[280px] w-full place-items-center rounded-3xl border border-dashed border-amber-200 bg-amber-50/40"
	>
		<div class="text-center">
			<p class="text-base font-black text-amber-700">ยังไม่มีข้อมูลความเสี่ยงเท้า</p>
			<p class="mt-1 text-sm font-semibold text-slate-500">
				กรุณาตรวจสอบไฟล์ foot_risk_summary.csv ในโฟลเดอร์ static
			</p>
		</div>
	</div>
{/if}
