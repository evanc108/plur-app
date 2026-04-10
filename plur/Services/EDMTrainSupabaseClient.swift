import Foundation
import Supabase

// MARK: - Supabase-backed EDMTrain Client

/// Queries the local Supabase cache instead of hitting the EDMTrain API directly.
/// Data is kept fresh by the `sync-edmtrain` Edge Function running on a schedule.
actor EDMTrainSupabaseClient: EDMTrainClientProtocol {

    private let client = SupabaseService.client

    // MARK: - Events

    func fetchEvents(_ request: EventRequest) async throws -> [EDMTrainEvent] {
        let params = SearchEventsParams(
            p_location_ids: request.locationIds.isEmpty ? nil : request.locationIds,
            p_artist_ids: request.artistIds.isEmpty ? nil : request.artistIds,
            p_venue_ids: request.venueIds.isEmpty ? nil : request.venueIds,
            p_event_name: request.eventName?.isEmpty == false ? request.eventName : nil,
            p_start_date: request.startDate.map(EDMTrainDateFormatter.string(from:)),
            p_end_date: request.endDate.map(EDMTrainDateFormatter.string(from:)),
            p_festival_only: request.festivalOnly,
            p_include_electronic: request.includeElectronic,
            p_include_other_genres: request.includeOtherGenres,
            p_limit: request.limit,
            p_offset: request.offset
        )

        let response: Data = try await client
            .rpc("search_events", params: params)
            .execute()
            .data

        let decoder = JSONDecoder()
        return try decoder.decode([EDMTrainEvent].self, from: response)
    }

    // MARK: - Locations

    func fetchLocations(_ request: LocationRequest) async throws -> [EDMTrainLocation] {
        var query = client
            .from("edmtrain_locations")
            .select()

        if let state = request.state, !state.isEmpty {
            query = query.eq("state_code", value: state)
        }
        if let city = request.city, !city.isEmpty {
            query = query.eq("city", value: city)
        }

        let data: Data = try await query
            .order("state_code")
            .order("city")
            .execute()
            .data

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([EDMTrainLocation].self, from: data)
    }
}

// MARK: - RPC Params

private struct SearchEventsParams: Encodable {
    let p_location_ids: [Int]?
    let p_artist_ids: [Int]?
    let p_venue_ids: [Int]?
    let p_event_name: String?
    let p_start_date: String?
    let p_end_date: String?
    let p_festival_only: Bool
    let p_include_electronic: Bool
    let p_include_other_genres: Bool
    let p_limit: Int
    let p_offset: Int
}
