<script lang="ts">
	import { Canvas } from '@threlte/core';
	import Scene from './scene.svelte';
	import { MapEditor } from './editor.svelte';
	import { regionTypes } from 'rising-tides-data';

	const editor = new MapEditor();
</script>

<div class="flex h-screen">
	<div class="relative flex-1">
		<Canvas>
			<Scene
				bind:regions={editor.regions}
				bind:mapRadius={editor.mapRadius}
				selectedCells={editor.selectedCells}
				isSelecting={editor.isSelecting}
				isFillMode={editor.isFillMode}
				hoveredCell={editor.hoveredCell}
				onCellClick={editor.handleCellClick}
				onCellPointerDown={editor.handleCellPointerDown}
				onCellPointerEnter={editor.handleCellPointerEnter}
				onPointerUp={editor.handlePointerUp}
				onPointerLeave={editor.handlePointerLeave}
				getRegionForCell={editor.getRegionForCell}
			/>
		</Canvas>

		<div class="absolute top-4 left-4 rounded-lg bg-white/90 p-4 shadow-lg">
			<div class="mb-4">
				<label class="mb-1 block text-sm font-medium" for="radius-input">Map Radius</label>
				<input
					type="range"
					min="3"
					max="20"
					bind:value={editor.mapRadius}
					class="w-48"
					id="radius-input"
				/>
				<span class="ml-2 text-sm">{editor.mapRadius}</span>
			</div>

			{#if editor.isSelecting}
				<div class="space-y-2">
					<div class="mb-2 flex gap-1">
						<button
							onclick={() => editor.setSelectionMode('paint')}
							class="flex-1 rounded px-3 py-1 text-sm font-medium transition-colors"
							class:bg-blue-500={editor.selectionMode === 'paint'}
							class:text-white={editor.selectionMode === 'paint'}
							class:bg-gray-200={editor.selectionMode !== 'paint'}
						>
							🖌️ Paint
						</button>
						<button
							onclick={() => editor.setSelectionMode('erase')}
							class="flex-1 rounded px-3 py-1 text-sm font-medium transition-colors"
							class:bg-red-500={editor.selectionMode === 'erase'}
							class:text-white={editor.selectionMode === 'erase'}
							class:bg-gray-200={editor.selectionMode !== 'erase'}
						>
							🧹 Erase
						</button>
					</div>
					<div>
						<label class="mb-1 block text-sm font-medium" for="region-select">Region Type</label>
						<select
							bind:value={editor.selectedRegionType}
							class="w-full rounded border px-2 py-1"
							id="region-select"
						>
							{#each regionTypes as { id, name } (name)}
								<option value={id}>{name}</option>
							{/each}
						</select>
					</div>
					<div class="flex gap-2">
						<button
							onclick={editor.createRegion}
							disabled={editor.selectedCells.size === 0}
							class="rounded bg-blue-500 px-3 py-1 text-white disabled:opacity-50"
						>
							Create Region ({editor.selectedCells.size} cells)
						</button>
						<button
							onclick={editor.cancelSelection}
							class="rounded bg-gray-500 px-3 py-1 text-white"
						>
							Cancel
						</button>
					</div>
				</div>
			{:else if editor.isFillMode}
				<div class="space-y-2">
					<div>
						<label class="mb-1 block text-sm font-medium" for="region-select-fill"
							>Region Type</label
						>
						<select
							bind:value={editor.selectedRegionType}
							class="w-full rounded border px-2 py-1"
							id="region-select-fill"
						>
							{#each regionTypes as { id, name } (name)}
								<option value={id}>{name}</option>
							{/each}
						</select>
					</div>
					<p class="text-sm text-gray-600">Click anywhere to fill all unpainted cells</p>
					<button onclick={editor.cancelFillMode} class="rounded bg-gray-500 px-3 py-1 text-white">
						Cancel
					</button>
				</div>
			{:else}
				<div class="space-y-2">
					<button
						onclick={editor.startSelection}
						class="w-full rounded bg-green-500 px-4 py-2 text-white"
					>
						Start Selection
					</button>
					<button
						onclick={editor.startFillMode}
						class="w-full rounded bg-purple-500 px-4 py-2 text-white"
					>
						Fill Unpainted
					</button>
				</div>
			{/if}
		</div>
	</div>

	<div class="w-80 overflow-y-auto bg-gray-100 p-4">
		<div class="mb-4 flex items-center justify-between">
			<h2 class="text-xl font-bold">Regions</h2>
			<button
				onclick={editor.copyRegionsToClipboard}
				class="rounded bg-blue-500 px-3 py-1 text-sm text-white"
			>
				Copy JSON
			</button>
		</div>

		{#if editor.regions.length === 0}
			<p class="text-gray-500">No regions defined</p>
		{:else}
			<div class="space-y-2">
				{#each editor.regions as region, index (index)}
					<div
						class="cursor-pointer rounded bg-white p-3 shadow"
						class:ring-2={editor.selectedRegionIndex === index}
						class:ring-blue-500={editor.selectedRegionIndex === index}
						onclick={() => editor.selectRegion(index)}
						onkeydown={() => {}}
						tabindex={0}
						role="button"
					>
						<div class="flex items-start justify-between">
							<div class="flex-1">
								<div class="flex items-center gap-2">
									<div
										class="h-4 w-4 rounded"
										style="background-color: {region.type.debugColor}"
									></div>
									<span class="font-medium">{region.type.name}</span>
								</div>
								<p class="mt-1 text-sm text-gray-600">
									{region.coordinates.length} cells
								</p>
							</div>
							<button
								onclick={(e) => {
									e.stopPropagation();
									editor.deleteRegion(index);
								}}
								class="text-red-500 hover:text-red-700"
							>
								×
							</button>
						</div>

						{#if editor.selectedRegionIndex === index}
							<div class="mt-2 border-t pt-2">
								<p class="text-xs text-gray-500">Coordinates:</p>
								<div class="mt-1 max-h-32 overflow-y-auto text-xs">
									{#each region.coordinates as coord, i (i)}
										<span class="m-0.5 inline-block rounded bg-gray-200 px-1 py-0.5">
											q:{coord.q}, r:{coord.r}
										</span>
									{/each}
								</div>
							</div>
						{/if}
					</div>
				{/each}
			</div>
		{/if}

		<div class="mt-6 rounded bg-gray-200 p-3">
			<h3 class="mb-2 font-medium">Instructions</h3>
			<ul class="space-y-1 text-sm">
				<li>• Click "Start Selection" to begin</li>
				<li>• Use Paint mode to select cells</li>
				<li>• Use Erase mode to deselect cells</li>
				<li>• Click and drag to select/erase multiple</li>
				<li>• Use "Fill Unpainted" to fill remaining cells</li>
				<li>• Choose region type and create</li>
				<li>• Click regions to view details</li>
				<li>• Use "Copy JSON" to export data</li>
			</ul>
		</div>
	</div>
</div>
