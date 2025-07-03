import { cubicOut, cubicIn, cubicInOut, expoInOut, quadInOut, sineInOut } from 'svelte/easing';

export class Boat {
	// Position for smooth interpolation
	currentX = $state(0);
	currentZ = $state(0);
	currentRotation = $state(0);

	// Bobbing animation
	bobOffset = $state(0);
	bobTime = 0;

	// Current hex coordinates
	q = $state(0);
	r = $state(0);

	// Movement state
	isMoving = $state(false);
	currentPath: Array<{ q: number; r: number }> = [];

	// Smooth path following
	pathProgress = 0;
	totalPathLength = 0;
	pathSegments: Array<{
		start: { x: number; z: number };
		end: { x: number; z: number };
		length: number;
	}> = [];
	movementSpeed = 2; // units per second

	constructor(startQ: number, startR: number, hexSize: number = 1) {
		this.q = startQ;
		this.r = startR;

		// Set initial world position
		const worldPos = this.hexToWorld(startQ, startR, hexSize);
		this.currentX = worldPos.x;
		this.currentZ = worldPos.z;
	}

	hexToWorld(q: number, r: number, hexSize: number = 1) {
		return {
			x: hexSize * Math.sqrt(3) * (q + r / 2),
			z: ((hexSize * 3) / 2) * r
		};
	}

	setPath(path: Array<{ q: number; r: number }>, hexSize: number = 1) {
		if (path.length === 0) return;

		this.currentPath = path;
		this.isMoving = true;
		this.pathProgress = 0;

		// Build path segments
		this.pathSegments = [];
		let currentPos = { x: this.currentX, z: this.currentZ };

		for (const hex of path) {
			const nextPos = this.hexToWorld(hex.q, hex.r, hexSize);
			const length = Math.sqrt(
				Math.pow(nextPos.x - currentPos.x, 2) + Math.pow(nextPos.z - currentPos.z, 2)
			);

			this.pathSegments.push({
				start: { ...currentPos },
				end: nextPos,
				length
			});

			currentPos = nextPos;
		}

		// Calculate total path length
		this.totalPathLength = this.pathSegments.reduce((sum, seg) => sum + seg.length, 0);
	}

	update(deltaTime: number) {
		if (!this.isMoving || this.pathSegments.length === 0) return;

		// Update path progress
		const deltaProgress = (deltaTime * this.movementSpeed) / this.totalPathLength;
		this.pathProgress = Math.min(1, this.pathProgress + deltaProgress);

		// Apply easing to the progress
		const easedProgress = sineInOut(this.pathProgress);

		// Find current position along the path
		const position = this.getPositionAtProgress(easedProgress);

		// Update position
		this.currentX = position.x;
		this.currentZ = position.z;

		// Update rotation to face movement direction
		if (position.dx !== 0 || position.dz !== 0) {
			const targetRotation = Math.atan2(position.dz, position.dx) - Math.PI / 2;
			// Smooth rotation interpolation
			const rotationDiff = this.normalizeAngle(targetRotation - this.currentRotation);
			this.currentRotation += rotationDiff * Math.min(1, deltaTime * 0.01);
		}

		// Check if movement is complete
		if (this.pathProgress >= 1) {
			this.isMoving = false;
			// Update final hex coordinates
			const lastHex = this.currentPath[this.currentPath.length - 1];
			this.q = lastHex.q;
			this.r = lastHex.r;
			// Clear path preview
			this.pathProgress = 0;
			this.currentPath = [];
		}
	}

	getPositionAtProgress(progress: number): { x: number; z: number; dx: number; dz: number } {
		const totalDistance = this.totalPathLength * progress;
		let accumulatedDistance = 0;

		for (let i = 0; i < this.pathSegments.length; i++) {
			const segment = this.pathSegments[i];

			if (accumulatedDistance + segment.length >= totalDistance) {
				// We're in this segment
				const segmentProgress = (totalDistance - accumulatedDistance) / segment.length;
				const x = segment.start.x + (segment.end.x - segment.start.x) * segmentProgress;
				const z = segment.start.z + (segment.end.z - segment.start.z) * segmentProgress;

				// Calculate direction for rotation
				const dx = segment.end.x - segment.start.x;
				const dz = segment.end.z - segment.start.z;

				return { x, z, dx, dz };
			}

			accumulatedDistance += segment.length;
		}

		// Return end position if we somehow go past
		const lastSegment = this.pathSegments[this.pathSegments.length - 1];
		return {
			x: lastSegment.end.x,
			z: lastSegment.end.z,
			dx: lastSegment.end.x - lastSegment.start.x,
			dz: lastSegment.end.z - lastSegment.start.z
		};
	}

	normalizeAngle(angle: number): number {
		while (angle > Math.PI) angle -= 2 * Math.PI;
		while (angle < -Math.PI) angle += 2 * Math.PI;
		return angle;
	}

	updateBobbing(deltaTime: number) {
		this.bobTime += deltaTime * 0.002;
		this.bobOffset = Math.sin(this.bobTime) * 0.05 + Math.sin(this.bobTime * 1.5) * 0.02;
	}
}
