import { Tween } from 'svelte/motion';
import { cubicOut } from 'svelte/easing';

export enum RegionType {
	OCEAN = 0,
	PORT = 1,
	SHALLOW_WATER = 2,
	DEEP_WATER = 3,
	REEF = 4,
	STORM = 5
}

export class HexCell {
	y = new Tween(0, { easing: cubicOut, duration: 250 });

	// World position calculated from axial coordinates
	x: number;
	z: number;

	constructor(
		public q: number, // axial coordinate
		public r: number, // axial coordinate
		hexSize: number = 1,
		public regionType: RegionType = RegionType.OCEAN
	) {
		// Convert axial to world position (pointy-top hexagons)
		this.x = hexSize * Math.sqrt(3) * (q + r / 2);
		this.z = ((hexSize * 3) / 2) * r;
	}
}
