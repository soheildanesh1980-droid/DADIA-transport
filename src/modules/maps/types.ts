export interface Coordinates {
  latitude: number;
  longitude: number;
}

export interface RouteEstimate {
  distanceKm: number;
  durationMin: number;
  provider: string;
}

export interface MapProvider {
  readonly name: string;

  calculateDistance(
    origin: Coordinates,
    destination: Coordinates
  ): number;

  estimateRoute(
    origin: Coordinates,
    destination: Coordinates
  ): RouteEstimate;
}
