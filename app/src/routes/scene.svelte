<script lang="ts">
	import { T, useTask } from '@threlte/core';
	import { Gizmo, Instance, InstancedMesh, interactivity, OrbitControls } from '@threlte/extras';
	import { HexCell, RegionType } from './hex-cell.svelte';
	import { Boat } from './boat.svelte';
	import { findPath } from './pathfinding';

	// Hex grid parameters
	const mapRadius = 16; // Creates a hexagonal map with radius 16
	const hexSize = 1;

	// Create boat at center
	const boat = new Boat(0, 0, hexSize);

	let pathPreview = $state<Array<{ q: number; r: number }>>([]);

	// Region colors
	const regionColors = {
		[RegionType.OCEAN]: '#4a90e2',
		[RegionType.PORT]: '#8b7355',
		[RegionType.SHALLOW_WATER]: '#6bb6ff',
		[RegionType.DEEP_WATER]: '#2c5aa0',
		[RegionType.REEF]: '#ff6b9d',
		[RegionType.STORM]: '#4a4a4a'
	};

	// Function to determine region type based on position
	function getRegionType(q: number, r: number): RegionType {
		// Center hex is a port
		if (q === 0 && r === 0) return RegionType.PORT;

		// Create port clusters
		if (
			(q === 0 && r === 0) ||
			(q === 6 && r === -3) ||
			(q === -6 && r === 3) ||
			(q === -3 && r === -3) ||
			(q === 3 && r === 3)
		) {
			return RegionType.PORT;
		}

		// Adjacent to ports are also ports (to make them visible)
		const portCenters = [
			[0, 0],
			[6, -3],
			[-6, 3],
			[-3, -3],
			[3, 3]
		];
		for (const [pq, pr] of portCenters) {
			const dist = (Math.abs(q - pq) + Math.abs(r - pr) + Math.abs(-q - r - (-pq - pr))) / 2;
			if (dist === 1) return RegionType.PORT;
		}

		// Create some reef areas
		if (
			(q >= 8 && q <= 10 && r >= -2 && r <= 0) ||
			(q >= -10 && q <= -8 && r >= 0 && r <= 2) ||
			(q >= -2 && q <= 2 && r >= 8 && r <= 10)
		) {
			return RegionType.REEF;
		}

		// Storm regions
		if ((q <= -10 && r >= 8) || (q >= 10 && r <= -8)) {
			return RegionType.STORM;
		}

		// Deep water at the edges
		const distance = (Math.abs(q) + Math.abs(r) + Math.abs(-q - r)) / 2;
		if (distance >= 12) return RegionType.DEEP_WATER;

		// Shallow water in between
		if (distance >= 7) return RegionType.SHALLOW_WATER;

		// Default ocean
		return RegionType.OCEAN;
	}

	// Create hex grid using axial coordinates
	const instances: HexCell[] = [];

	// Generate hexagonal shaped map
	for (let q = -mapRadius; q <= mapRadius; q++) {
		const r1 = Math.max(-mapRadius, -q - mapRadius);
		const r2 = Math.min(mapRadius, -q + mapRadius);

		for (let r = r1; r <= r2; r++) {
			const regionType = getRegionType(q, r);
			instances.push(new HexCell(q, r, hexSize, regionType));
		}
	}

	// Group instances by region type for efficient rendering
	const instancesByRegion = instances.reduce(
		(acc, instance) => {
			if (!acc[instance.regionType]) {
				acc[instance.regionType] = [];
			}
			acc[instance.regionType].push(instance);
			return acc;
		},
		{} as Record<RegionType, HexCell[]>
	);

	interactivity();

	// Helper to check if position is valid
	function isValidPosition(q: number, r: number): boolean {
		const s = -q - r;
		return Math.abs(q) <= mapRadius && Math.abs(r) <= mapRadius && Math.abs(s) <= mapRadius;
	}

	// Handle hex click
	function handleHexClick(q: number, r: number) {
		// Don't move if already moving
		if (boat.isMoving) return;

		// Find path from boat to clicked hex
		const path = findPath(boat.q, boat.r, q, r, isValidPosition, getRegionType);

		if (path) {
			pathPreview = path;
			boat.setPath(path, hexSize);
		}
	}

	// Update boat animation and movement
	useTask((delta) => {
		boat.updateBobbing(delta);
		boat.update(delta);
		// Clear path preview when movement is done
		if (!boat.isMoving && pathPreview.length > 0) {
			pathPreview = [];
		}
	});
</script>

<T.PerspectiveCamera
	makeDefault
	position={[boat.currentX + 10, 20, boat.currentZ + 10]}
	lookAt.x={boat.currentX}
	lookAt.z={boat.currentZ}
>
	<OrbitControls
		target={[boat.currentX, 0, boat.currentZ]}
		enablePan={false}
		minDistance={20}
		maxDistance={150}
		maxPolarAngle={Math.PI / 2.5}
	>
		<Gizmo />
	</OrbitControls>
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

<!-- Render each region type separately with its own color -->
{#each Object.entries(instancesByRegion) as [regionType, regionInstances], i (i)}
	<InstancedMesh>
		<T.CylinderGeometry args={[hexSize * 0.95, hexSize * 0.95, 0.22, 6, 1]}></T.CylinderGeometry>
		<T.MeshStandardMaterial color={regionColors[Number(regionType) as RegionType]}
		></T.MeshStandardMaterial>

		{#each regionInstances as instance (`${instance.q}.${instance.r}-${regionType}`)}
			<Instance
				position={[instance.x, instance.y.current, instance.z]}
				onpointerenter={() => instance.y.set(0.1)}
				onpointerleave={() => instance.y.set(0)}
				onclick={() => handleHexClick(instance.q, instance.r)}
			></Instance>
		{/each}
	</InstancedMesh>
{/each}

<!-- Path preview -->
{#if pathPreview.length > 0}
	{#each pathPreview as hex, i (i)}
		<T.Mesh
			position={[hexSize * Math.sqrt(3) * (hex.q + hex.r / 2), 0.3, ((hexSize * 3) / 2) * hex.r]}
		>
			<T.CylinderGeometry args={[hexSize * 0.3, hexSize * 0.3, 0.1, 6, 1]} />
			<T.MeshStandardMaterial color="#ffff00" opacity={0.5} transparent />
		</T.Mesh>
	{/each}
{/if}

<!-- Boat -->
<T.Group
	position={[boat.currentX, 0.5 + boat.bobOffset, boat.currentZ]}
	rotation.y={boat.currentRotation}
>
	<!-- Hull -->
	<T.Mesh position.y={0}>
		<T.BoxGeometry args={[0.3, 0.2, 0.8]} />
		<T.MeshStandardMaterial color="#8B4513" />
	</T.Mesh>

	<!-- Sail mast -->
	<T.Mesh position={[0, 0.5, 0]}>
		<T.CylinderGeometry args={[0.02, 0.02, 1]} />
		<T.MeshStandardMaterial color="#654321" />
	</T.Mesh>

	<!-- Sail -->
	<T.Mesh position={[0, 0.5, 0.1]} rotation.y={Math.PI / 2}>
		<T.PlaneGeometry args={[0.6, 0.8]} />
		<T.MeshStandardMaterial color="#FFFFFF" side={2} />
	</T.Mesh>
</T.Group>
