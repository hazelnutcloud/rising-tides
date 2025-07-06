import { Tween } from 'svelte/motion';
import { cubicOut } from 'svelte/easing';
import { regionTypes, type RegionType } from 'rising-tides-data';

export class HexCell {
	y = new Tween(0, { easing: cubicOut, duration: 250 });

	// World position calculated from axial coordinates
	x: number;
	z: number;

	constructor(
		public q: number, // axial coordinate
		public r: number, // axial coordinate
		hexSize: number = 1,
		public regionType: RegionType = regionTypes[0]
	) {
		// Convert axial to world position (pointy-top hexagons)
		this.x = hexSize * Math.sqrt(3) * (q + r / 2);
		this.z = ((hexSize * 3) / 2) * r;
	}
}
