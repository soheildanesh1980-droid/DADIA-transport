import type {
  Coordinates,
  MapProvider,
  RouteEstimate
} from "./types.js";

function validateCoordinates(point: Coordinates) {
  if (
    !Number.isFinite(point.latitude) ||
    !Number.isFinite(point.longitude) ||
    point.latitude < -90 ||
    point.latitude > 90 ||
    point.longitude < -180 ||
    point.longitude > 180
  ) {
    throw new Error("invalid_coordinates");
  }
}

function haversineKm(
  origin: Coordinates,
  destination: Coordinates
): number {
  validateCoordinates(origin);
  validateCoordinates(destination);

  const earthRadiusKm = 6371;

  const lat1 = origin.latitude * Math.PI / 180;
  const lat2 = destination.latitude * Math.PI / 180;
  const dLat =
    (destination.latitude - origin.latitude) * Math.PI / 180;
  const dLon =
    (destination.longitude - origin.longitude) * Math.PI / 180;

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) *
      Math.cos(lat2) *
      Math.sin(dLon / 2) ** 2;

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return earthRadiusKm * c;
}

export class HaversineMapProvider implements MapProvider {
  readonly name = "haversine";

  calculateDistance(
    origin: Coordinates,
    destination: Coordinates
  ): number {
    return haversineKm(origin, destination);
  }

  estimateRoute(
    origin: Coordinates,
    destination: Coordinates
  ): RouteEstimate {
    const distanceKm = this.calculateDistance(origin, destination);

    const averageSpeedKmH = 30;
    const durationMin =
      distanceKm === 0
        ? 0
        : Math.max(
            1,
            Math.ceil((distanceKm / averageSpeedKmH) * 60)
          );

    return {
      distanceKm: Number(distanceKm.toFixed(3)),
      durationMin,
      provider: this.name
    };
  }
}
