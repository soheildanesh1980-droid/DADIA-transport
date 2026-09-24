export interface CreateRatingInput {
  raterId: string;
  ratedUserId: string;
  tripId?: string | null;
  score: number;
  comment?: string | null;
}
