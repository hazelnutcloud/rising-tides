import {
	regionTypes,
	type Region,
	type Coordinate,
	type RegionType,
	type Map
} from 'rising-tides-data';

export class MapEditor {
	regions = $state<Region[]>([]);
	mapRadius = $state(16);
	selectedRegionIndex = $state<number | null>(null);
	selectedRegionId = $state<RegionType['id']>(regionTypes[0].id);
	selectedRegionType = $derived<RegionType>(
		regionTypes.find(({ id }) => id === this.selectedRegionId)!
	);
	isSelecting = $state(false);
	isFillMode = $state(false);
	selectedCells = $state<Set<string>>(new Set());
	isDragging = $state(false);
	selectionMode = $state<'paint' | 'erase'>('paint');
	hoveredCell = $state<string | null>(null);

	handleCellClick = (q: number, r: number) => {
		const cellKey = `${q},${r}`;

		if (this.isFillMode) {
			this.fillUnpaintedCells();
		} else if (this.isSelecting) {
			if (this.selectionMode === 'paint') {
				this.selectedCells.add(cellKey);
			} else {
				this.selectedCells.delete(cellKey);
			}
			this.selectedCells = new Set(this.selectedCells);
		}
	};

	handleCellPointerDown = (q: number, r: number) => {
		if (this.isSelecting) {
			this.isDragging = true;
			this.handleCellClick(q, r);
		}
	};

	handleCellPointerEnter = (q: number, r: number) => {
		const cellKey = `${q},${r}`;
		this.hoveredCell = cellKey;

		if (this.isSelecting && this.isDragging) {
			if (this.selectionMode === 'paint') {
				this.selectedCells.add(cellKey);
			} else {
				this.selectedCells.delete(cellKey);
			}
			this.selectedCells = new Set(this.selectedCells);
		}
	};

	handlePointerUp = () => {
		this.isDragging = false;
	};

	handlePointerLeave = () => {
		this.hoveredCell = null;
	};

	createRegion = () => {
		if (this.selectedCells.size === 0) return;

		// Remove selected cells from any existing regions
		this.removeCellsFromExistingRegions(this.selectedCells);

		const coordinates: Coordinate[] = Array.from(this.selectedCells).map((key) => {
			const [q, r] = key.split(',').map(Number);
			return { q, r };
		});

		this.regions.push({
			type: this.selectedRegionType,
			availableFishIds: { day: [], night: [] },
			coordinates
		});

		this.selectedCells.clear();
		this.selectedCells = new Set();
		this.isSelecting = false;
	};

	deleteRegion = (index: number) => {
		this.regions.splice(index, 1);
		if (this.selectedRegionIndex === index) {
			this.selectedRegionIndex = null;
		}
	};

	copyRegionsToClipboard = () => {
		const regionData = JSON.stringify(
			this.regions.map((region) => ({ ...region, type: region.type.id })) satisfies Map['regions'],
			null,
			2
		);
		navigator.clipboard.writeText(regionData);
	};

	getRegionForCell = (q: number, r: number): { region: Region; index: number } | null => {
		for (let i = 0; i < this.regions.length; i++) {
			const region = this.regions[i];
			for (const coord of region.coordinates) {
				if (coord.q === q && coord.r === r) {
					return { region, index: i };
				}
			}
		}
		return null;
	};

	startSelection = () => {
		this.isSelecting = true;
		this.selectionMode = 'paint';
	};

	setSelectionMode = (mode: 'paint' | 'erase') => {
		this.selectionMode = mode;
	};

	cancelSelection = () => {
		this.isSelecting = false;
		this.selectedCells.clear();
		this.selectedCells = new Set();
	};

	selectRegion = (index: number) => {
		this.selectedRegionIndex = this.selectedRegionIndex === index ? null : index;
	};

	removeCellsFromExistingRegions = (cellsToRemove: Set<string>) => {
		// Remove cells from any existing regions
		for (const region of this.regions) {
			region.coordinates = region.coordinates.filter((coord) => {
				const cellKey = `${coord.q},${coord.r}`;
				return !cellsToRemove.has(cellKey);
			});
		}

		// Remove any regions that now have no cells
		this.regions = this.regions.filter((region) => region.coordinates.length > 0);
	};

	startFillMode = () => {
		this.isFillMode = true;
		this.isSelecting = false;
		this.selectedCells.clear();
		this.selectedCells = new Set();
	};

	cancelFillMode = () => {
		this.isFillMode = false;
	};

	fillUnpaintedCells = () => {
		// Get all cells in the current map
		const allCells = new Set<string>();
		for (let q = -this.mapRadius; q <= this.mapRadius; q++) {
			const r1 = Math.max(-this.mapRadius, -q - this.mapRadius);
			const r2 = Math.min(this.mapRadius, -q + this.mapRadius);
			for (let r = r1; r <= r2; r++) {
				allCells.add(`${q},${r}`);
			}
		}

		// Find cells that are already in regions
		const paintedCells = new Set<string>();
		for (const region of this.regions) {
			for (const coord of region.coordinates) {
				paintedCells.add(`${coord.q},${coord.r}`);
			}
		}

		// Get unpainted cells
		const unpaintedCells = new Set<string>();
		for (const cell of allCells) {
			if (!paintedCells.has(cell)) {
				unpaintedCells.add(cell);
			}
		}

		// Create a new region with all unpainted cells
		if (unpaintedCells.size > 0) {
			const coordinates: Coordinate[] = Array.from(unpaintedCells).map((key) => {
				const [q, r] = key.split(',').map(Number);
				return { q, r };
			});

			this.regions.push({
				type: this.selectedRegionType,
				availableFishIds: { day: [], night: [] },
				coordinates
			});

			this.isFillMode = false;
		}
	};
}
