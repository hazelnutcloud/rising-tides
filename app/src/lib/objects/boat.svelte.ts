import { sineInOut } from 'svelte/easing';

interface Point {
	x: number;
	z: number;
}

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

	// Smooth path following with splines
	pathProgress = 0;
	splinePoints: Point[] = [];
	totalSplineLength = 0;
	splineSegmentLengths: number[] = [];
	movementSpeed = 1; // units per second

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

	// Catmull-Rom spline interpolation
	catmullRom(p0: Point, p1: Point, p2: Point, p3: Point, t: number): Point {
		const t2 = t * t;
		const t3 = t2 * t;

		const x =
			0.5 *
			(2 * p1.x +
				(-p0.x + p2.x) * t +
				(2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
				(-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3);

		const z =
			0.5 *
			(2 * p1.z +
				(-p0.z + p2.z) * t +
				(2 * p0.z - 5 * p1.z + 4 * p2.z - p3.z) * t2 +
				(-p0.z + 3 * p1.z - 3 * p2.z + p3.z) * t3);

		return { x, z };
	}

	// Calculate spline segment length using sampling
	calculateSegmentLength(p0: Point, p1: Point, p2: Point, p3: Point, samples: number = 10): number {
		let length = 0;
		let prevPoint = this.catmullRom(p0, p1, p2, p3, 0);

		for (let i = 1; i <= samples; i++) {
			const t = i / samples;
			const point = this.catmullRom(p0, p1, p2, p3, t);
			const dx = point.x - prevPoint.x;
			const dz = point.z - prevPoint.z;
			length += Math.sqrt(dx * dx + dz * dz);
			prevPoint = point;
		}

		return length;
	}

	setPath(path: Array<{ q: number; r: number }>, hexSize: number = 1) {
		if (path.length === 0) return;

		this.currentPath = path;
		this.isMoving = true;
		this.pathProgress = 0;

		// Convert hex path to world coordinates
		this.splinePoints = [
			{ x: this.currentX, z: this.currentZ }, // Start from current position
			...path.map((hex) => this.hexToWorld(hex.q, hex.r, hexSize))
		];

		// For Catmull-Rom, we need to add control points at the beginning and end
		// Duplicate first and last points for smoother start/end
		if (this.splinePoints.length > 1) {
			const first = this.splinePoints[0];
			const second = this.splinePoints[1];
			const beforeFirst = {
				x: first.x - (second.x - first.x),
				z: first.z - (second.z - first.z)
			};
			this.splinePoints.unshift(beforeFirst);

			const last = this.splinePoints[this.splinePoints.length - 1];
			const secondLast = this.splinePoints[this.splinePoints.length - 2];
			const afterLast = {
				x: last.x + (last.x - secondLast.x),
				z: last.z + (last.z - secondLast.z)
			};
			this.splinePoints.push(afterLast);
		}

		// Calculate segment lengths
		this.splineSegmentLengths = [];
		this.totalSplineLength = 0;

		// We have n+2 points (including control points), so n-1 segments
		for (let i = 0; i < this.splinePoints.length - 3; i++) {
			const length = this.calculateSegmentLength(
				this.splinePoints[i],
				this.splinePoints[i + 1],
				this.splinePoints[i + 2],
				this.splinePoints[i + 3]
			);
			this.splineSegmentLengths.push(length);
			this.totalSplineLength += length;
		}
	}

	update(deltaTime: number) {
		if (!this.isMoving || this.splinePoints.length < 4) return;

		// Update path progress
		const deltaProgress = (deltaTime * this.movementSpeed) / this.totalSplineLength;
		this.pathProgress = Math.min(1, this.pathProgress + deltaProgress);

		// Apply easing
		const easedProgress = sineInOut(this.pathProgress);

		// Find position on spline
		const position = this.getSplinePosition(easedProgress);

		// Update position
		this.currentX = position.x;
		this.currentZ = position.z;

		// Update rotation to face movement direction
		if (position.dx !== 0 || position.dz !== 0) {
			const targetRotation = Math.atan2(position.dz, position.dx) - Math.PI / 2;
			const rotationDiff = this.normalizeAngle(targetRotation - this.currentRotation);
			this.currentRotation += rotationDiff * Math.min(1, deltaTime * 0.01);
		}

		// Check if movement is complete
		if (this.pathProgress >= 1) {
			this.isMoving = false;
			const lastHex = this.currentPath[this.currentPath.length - 1];
			this.q = lastHex.q;
			this.r = lastHex.r;
			this.pathProgress = 0;
			this.currentPath = [];
		}
	}

	getSplinePosition(progress: number): { x: number; z: number; dx: number; dz: number } {
		const targetDistance = this.totalSplineLength * progress;
		let accumulatedDistance = 0;

		// Find which segment we're in
		for (let i = 0; i < this.splineSegmentLengths.length; i++) {
			const segmentLength = this.splineSegmentLengths[i];

			if (accumulatedDistance + segmentLength >= targetDistance) {
				// We're in this segment
				const segmentProgress = (targetDistance - accumulatedDistance) / segmentLength;

				// Get the four control points for this segment
				const p0 = this.splinePoints[i];
				const p1 = this.splinePoints[i + 1];
				const p2 = this.splinePoints[i + 2];
				const p3 = this.splinePoints[i + 3];

				// Get position on spline
				const pos = this.catmullRom(p0, p1, p2, p3, segmentProgress);

				// Calculate derivative for rotation (using small delta)
				const delta = 0.01;
				const nextT = Math.min(1, segmentProgress + delta);
				const nextPos = this.catmullRom(p0, p1, p2, p3, nextT);

				return {
					x: pos.x,
					z: pos.z,
					dx: nextPos.x - pos.x,
					dz: nextPos.z - pos.z
				};
			}

			accumulatedDistance += segmentLength;
		}

		// Return end position if we somehow go past
		const lastPoint = this.splinePoints[this.splinePoints.length - 2]; // -2 because last is control point
		return { x: lastPoint.x, z: lastPoint.z, dx: 0, dz: 0 };
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
