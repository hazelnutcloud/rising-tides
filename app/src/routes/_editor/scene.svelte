<script lang="ts">
	import { T } from '@threlte/core';
	import { Instance, InstancedMesh, interactivity, OrbitControls } from '@threlte/extras';
	import { HexCell } from '$lib/objects/hex-cell.svelte';
	import { type Region } from 'rising-tides-data';

	let {
		regions = $bindable(),
		mapRadius = $bindable(),
		selectedCells,
		isSelecting,
		isFillMode,
		hoveredCell,
		onCellClick,
		onCellPointerDown,
		onCellPointerEnter,
		onPointerUp,
		onPointerLeave,
		getRegionForCell
	}: {
		regions: Region[];
		mapRadius: number;
		selectedCells: Set<string>;
		isSelecting: boolean;
		isFillMode: boolean;
		hoveredCell: string | null;
		onCellClick: (q: number, r: number) => void;
		onCellPointerDown: (q: number, r: number) => void;
		onCellPointerEnter: (q: number, r: number) => void;
		onPointerUp: () => void;
		onPointerLeave: () => void;
		getRegionForCell: (q: number, r: number) => { region: Region; index: number } | null;
	} = $props();

	// Hex grid parameters
	const hexSize = 1;

	// Create hex grid using axial coordinates
	let instances = $derived.by(() => {
		const cells: HexCell[] = [];

		// Generate hexagonal shaped map
		for (let q = -mapRadius; q <= mapRadius; q++) {
			let r = Math.max(-mapRadius, -q - mapRadius);
			const s = Math.min(mapRadius, -q + mapRadius);

			for (r; r <= s; r++) {
				cells.push(new HexCell(q, r, hexSize));
			}
		}

		return cells;
	});

	interactivity();

	// Add global pointer up handler
	$effect(() => {
		const handleGlobalPointerUp = () => onPointerUp();
		window.addEventListener('pointerup', handleGlobalPointerUp);
		return () => window.removeEventListener('pointerup', handleGlobalPointerUp);
	});
</script>

<T.PerspectiveCamera position={[0, 60, 0]} makeDefault>
	<OrbitControls enableRotate={false}></OrbitControls>
</T.PerspectiveCamera>

<T.DirectionalLight position={[10, 10, 5]} intensity={1} />
<T.AmbientLight intensity={0.5} />

<!-- Border layer -->
<InstancedMesh>
	<T.CylinderGeometry args={[hexSize, hexSize, 0.2, 6, 1]}></T.CylinderGeometry>
	<T.MeshStandardMaterial color="#1a1a1a"></T.MeshStandardMaterial>

	{#each instances as instance (`${instance.q}.${instance.r}-border`)}
		<Instance position={[instance.x, instance.y.current - 0.01, instance.z]}></Instance>
	{/each}
</InstancedMesh>

<!-- Main hex cells -->
{#each instances as instance (`${instance.q}.${instance.r}`)}
	{@const regionData = getRegionForCell(instance.q, instance.r)}
	{@const cellKey = `${instance.q},${instance.r}`}
	{@const isSelected = selectedCells.has(cellKey)}
	{@const isHovered = hoveredCell === cellKey}
	{@const color = isSelected
		? '#FFD700'
		: isHovered && isSelecting
			? '#FFA500'
			: regionData
				? regionData.region.type.debugColor
				: instance.q === 0 && instance.r === 0
					? '#AAAAAA'
					: '#E0E0E0'}

	<T.Mesh
		position={[instance.x, instance.y.current, instance.z]}
		onpointerenter={() => {
			onCellPointerEnter(instance.q, instance.r);
			if (!isSelecting && !isFillMode) instance.y.set(0.1);
		}}
		onpointerleave={() => {
			onPointerLeave();
			if (!isSelecting && !isFillMode) instance.y.set(0);
		}}
		onpointerdown={() => onCellPointerDown(instance.q, instance.r)}
		onclick={() => onCellClick(instance.q, instance.r)}
	>
		<T.CylinderGeometry args={[hexSize * 0.95, hexSize * 0.95, 0.22, 6, 1]} />
		<T.MeshStandardMaterial {color} />
	</T.Mesh>
{/each}
