interface HexNode {
	q: number;
	r: number;
	g: number; // Cost from start
	h: number; // Heuristic cost to end
	f: number; // Total cost (g + h)
	parent: HexNode | null;
}

// Calculate hex distance (heuristic)
function hexDistance(q1: number, r1: number, q2: number, r2: number): number {
	return (Math.abs(q1 - q2) + Math.abs(q1 + r1 - q2 - r2) + Math.abs(r1 - r2)) / 2;
}

// Get hex neighbors
function getNeighbors(q: number, r: number): Array<{ q: number; r: number }> {
	return [
		{ q: q + 1, r: r }, // East
		{ q: q + 1, r: r - 1 }, // Northeast
		{ q: q, r: r - 1 }, // Northwest
		{ q: q - 1, r: r }, // West
		{ q: q - 1, r: r + 1 }, // Southwest
		{ q: q, r: r + 1 } // Southeast
	];
}

// A* pathfinding for hex grid
export function findPath(
	startQ: number,
	startR: number,
	endQ: number,
	endR: number,
	isValidPosition: (q: number, r: number) => boolean
): Array<{ q: number; r: number }> | null {
	// Check if start and end are valid
	if (!isValidPosition(startQ, startR) || !isValidPosition(endQ, endR)) {
		return null;
	}

	const openSet: HexNode[] = [];
	const closedSet = new Set<string>();

	// Create start node
	const startNode: HexNode = {
		q: startQ,
		r: startR,
		g: 0,
		h: hexDistance(startQ, startR, endQ, endR),
		f: 0,
		parent: null
	};
	startNode.f = startNode.g + startNode.h;

	openSet.push(startNode);

	while (openSet.length > 0) {
		// Find node with lowest f score
		let currentIndex = 0;
		for (let i = 1; i < openSet.length; i++) {
			if (openSet[i].f < openSet[currentIndex].f) {
				currentIndex = i;
			}
		}

		const current = openSet.splice(currentIndex, 1)[0];
		const currentKey = `${current.q},${current.r}`;

		// Check if we reached the goal
		if (current.q === endQ && current.r === endR) {
			// Reconstruct path
			const path: Array<{ q: number; r: number }> = [];
			let node: HexNode | null = current;

			while (node !== null) {
				path.unshift({ q: node.q, r: node.r });
				node = node.parent;
			}

			// Remove start position from path
			path.shift();
			return path;
		}

		closedSet.add(currentKey);

		// Check all neighbors
		const neighbors = getNeighbors(current.q, current.r);

		for (const neighbor of neighbors) {
			const neighborKey = `${neighbor.q},${neighbor.r}`;

			// Skip if already evaluated or invalid
			if (closedSet.has(neighborKey) || !isValidPosition(neighbor.q, neighbor.r)) {
				continue;
			}

			const tentativeG = current.g;

			// Check if neighbor is already in open set
			let neighborNode = openSet.find((n) => n.q === neighbor.q && n.r === neighbor.r);

			if (!neighborNode) {
				// Create new neighbor node
				neighborNode = {
					q: neighbor.q,
					r: neighbor.r,
					g: tentativeG,
					h: hexDistance(neighbor.q, neighbor.r, endQ, endR),
					f: 0,
					parent: current
				};
				neighborNode.f = neighborNode.g + neighborNode.h;
				openSet.push(neighborNode);
			} else if (tentativeG < neighborNode.g) {
				// Found better path to neighbor
				neighborNode.g = tentativeG;
				neighborNode.f = neighborNode.g + neighborNode.h;
				neighborNode.parent = current;
			}
		}
	}

	// No path found
	return null;
}
