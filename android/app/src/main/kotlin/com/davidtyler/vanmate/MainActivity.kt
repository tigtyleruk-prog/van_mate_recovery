package com.davidtyler.vanmate

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.maps.model.LatLng
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.AutocompletePrediction
import com.google.android.libraries.places.api.model.AutocompleteSessionToken
import com.google.android.libraries.places.api.model.CircularBounds
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.model.RectangularBounds
import com.google.android.libraries.places.api.net.FetchPlaceRequest
import com.google.android.libraries.places.api.net.FindAutocompletePredictionsRequest
import com.google.android.libraries.places.api.net.PlacesClient
import com.google.android.libraries.places.api.net.SearchByTextRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var placesClient: PlacesClient? = null
    private val autocompleteSessions = mutableMapOf<String, AutocompleteSessionToken>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "van_mate/google_services"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMapsApiKey" -> {
                    try {
                        result.success(loadMapsApiKey())
                    } catch (exception: Exception) {
                        result.error(
                            "maps_api_key_unavailable",
                            exception.message,
                            null
                        )
                    }
                }

                "searchParkingPlaces" -> handleSearchParkingPlaces(call, result)
                "autocompletePlaces" -> handleAutocompletePlaces(call, result)
                "fetchAutocompletePlaceDetails" -> handleFetchAutocompletePlaceDetails(call, result)
                "clearAutocompleteSession" -> handleClearAutocompleteSession(call, result)
                "openNavigationChooser" -> handleOpenNavigationChooser(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleSearchParkingPlaces(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val query = call.argument<String>("query")?.trim().orEmpty()
        if (query.isBlank()) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }

        val apiKey = try {
            loadMapsApiKey()
        } catch (exception: Exception) {
            result.error("places_api_key_missing", exception.message, null)
            return
        }

        if (apiKey.isBlank()) {
            result.error(
                "places_api_key_missing",
                "No Android Maps/Places API key was found for Van Mate search.",
                null
            )
            return
        }

        val client = try {
            ensurePlacesClient(apiKey)
        } catch (exception: Exception) {
            val (code, message) = mapPlacesFailure(exception)
            result.error(code, message, null)
            return
        }

        val origin = buildOriginLatLng(
            call.argument<Number>("originLat"),
            call.argument<Number>("originLng")
        )

        val request = buildSearchRequest(query, origin)
        client.searchByText(request)
            .addOnSuccessListener { response ->
                val placeMaps = response.places
                    .mapNotNull { placeToMap(it) }
                    .take(12)
                result.success(placeMaps)
            }
            .addOnFailureListener { exception ->
                val (code, message) = mapPlacesFailure(exception)
                result.error(code, message, null)
            }
    }

    private fun handleAutocompletePlaces(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val query = call.argument<String>("query")?.trim().orEmpty()
        val sessionId = call.argument<String>("sessionId")?.trim().orEmpty()
        if (query.isBlank()) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }

        if (sessionId.isBlank()) {
            result.error(
                "places_invalid_session",
                "Google place autocomplete needs a valid session token.",
                null
            )
            return
        }

        val apiKey = try {
            loadMapsApiKey()
        } catch (exception: Exception) {
            result.error("places_api_key_missing", exception.message, null)
            return
        }

        if (apiKey.isBlank()) {
            result.error(
                "places_api_key_missing",
                "No Android Maps/Places API key was found for Van Mate search.",
                null
            )
            return
        }

        val client = try {
            ensurePlacesClient(apiKey)
        } catch (exception: Exception) {
            val (code, message) = mapPlacesFailure(exception)
            result.error(code, message, null)
            return
        }

        val origin = buildOriginLatLng(
            call.argument<Number>("originLat"),
            call.argument<Number>("originLng")
        )

        val request = buildAutocompleteRequest(
            query = query,
            sessionId = sessionId,
            origin = origin
        )

        client.findAutocompletePredictions(request)
            .addOnSuccessListener { response ->
                val predictions = response.autocompletePredictions
                    .mapNotNull { predictionToMap(it) }
                    .take(8)
                result.success(predictions)
            }
            .addOnFailureListener { exception ->
                val (code, message) = mapPlacesFailure(exception)
                result.error(code, message, null)
            }
    }

    private fun handleFetchAutocompletePlaceDetails(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val placeId = call.argument<String>("placeId")?.trim().orEmpty()
        val sessionId = call.argument<String>("sessionId")?.trim().orEmpty()
        if (placeId.isBlank()) {
            result.error(
                "places_details_failed",
                "Google place details need a valid place ID.",
                null
            )
            return
        }

        if (sessionId.isBlank()) {
            result.error(
                "places_invalid_session",
                "Google place details need a valid session token.",
                null
            )
            return
        }

        val apiKey = try {
            loadMapsApiKey()
        } catch (exception: Exception) {
            result.error("places_api_key_missing", exception.message, null)
            return
        }

        if (apiKey.isBlank()) {
            result.error(
                "places_api_key_missing",
                "No Android Maps/Places API key was found for Van Mate search.",
                null
            )
            return
        }

        val client = try {
            ensurePlacesClient(apiKey)
        } catch (exception: Exception) {
            val (code, message) = mapPlacesFailure(exception)
            result.error(code, message, null)
            return
        }

        val placeFields = listOf(
            Place.Field.ID,
            Place.Field.DISPLAY_NAME,
            Place.Field.FORMATTED_ADDRESS,
            Place.Field.LOCATION,
            Place.Field.TYPES,
        )
        val request = FetchPlaceRequest.builder(placeId, placeFields)
            .setSessionToken(resolveAutocompleteSessionToken(sessionId))
            .build()

        client.fetchPlace(request)
            .addOnSuccessListener { response ->
                autocompleteSessions.remove(sessionId)
                val placeMap = placeToMap(response.place)
                if (placeMap == null) {
                    result.error(
                        "places_details_failed",
                        "Google place details did not return a usable result.",
                        null
                    )
                    return@addOnSuccessListener
                }
                result.success(placeMap)
            }
            .addOnFailureListener { exception ->
                autocompleteSessions.remove(sessionId)
                val (code, message) = mapPlacesFailure(exception)
                result.error(code, message, null)
            }
    }

    private fun handleClearAutocompleteSession(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val sessionId = call.argument<String>("sessionId")?.trim().orEmpty()
        if (sessionId.isNotEmpty()) {
            autocompleteSessions.remove(sessionId)
        }
        result.success(null)
    }

    private fun handleOpenNavigationChooser(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val latitude = call.argument<Number>("latitude")?.toDouble()
        val longitude = call.argument<Number>("longitude")?.toDouble()
        val query = call.argument<String>("query")?.trim().orEmpty()

        val uri = if (latitude != null && longitude != null) {
            val encodedQuery = Uri.encode(query.ifBlank { "$latitude,$longitude" })
            Uri.parse("geo:$latitude,$longitude?q=$encodedQuery")
        } else {
            val encodedQuery = Uri.encode(query)
            Uri.parse("geo:0,0?q=$encodedQuery")
        }

        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            addCategory(Intent.CATEGORY_BROWSABLE)
        }

        val chooser = Intent.createChooser(intent, null)

        try {
            startActivity(chooser)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.success(false)
        }
    }

    private fun loadMapsApiKey(): String {
        val applicationInfo = packageManager.getApplicationInfo(
            packageName,
            PackageManager.GET_META_DATA
        )

        val mapsApiKey = applicationInfo.metaData
            ?.getString("com.google.android.geo.API_KEY")
            ?.trim()
            .orEmpty()

        return mapsApiKey
    }

    private fun ensurePlacesClient(apiKey: String): PlacesClient {
        if (!Places.isInitialized()) {
            Places.initializeWithNewPlacesApiEnabled(applicationContext, apiKey)
        }

        return placesClient ?: Places.createClient(this).also {
            placesClient = it
        }
    }

    private fun buildOriginLatLng(
        latitude: Number?,
        longitude: Number?
    ): LatLng? {
        if (latitude == null || longitude == null) {
            return null
        }

        return LatLng(latitude.toDouble(), longitude.toDouble())
    }

    private fun buildSearchRequest(
        query: String,
        origin: LatLng?
    ): SearchByTextRequest {
        val placeFields = listOf(
            Place.Field.ID,
            Place.Field.DISPLAY_NAME,
            Place.Field.FORMATTED_ADDRESS,
            Place.Field.LOCATION,
            Place.Field.TYPES,
        )

        val builder = SearchByTextRequest.builder(query, placeFields)
            .setMaxResultCount(12)
            .setRegionCode("GB")

        if (origin != null) {
            builder.setLocationBias(
                CircularBounds.newInstance(origin, 50_000.0)
            )
        } else {
            builder.setLocationRestriction(
                RectangularBounds.newInstance(
                    LatLng(49.5, -8.8),
                    LatLng(61.0, 2.2)
                )
            )
        }

        return builder.build()
    }

    private fun buildAutocompleteRequest(
        query: String,
        sessionId: String,
        origin: LatLng?
    ): FindAutocompletePredictionsRequest {
        val builder = FindAutocompletePredictionsRequest.builder()
            .setQuery(query)
            .setCountries(listOf("GB"))
            .setSessionToken(resolveAutocompleteSessionToken(sessionId))

        if (origin != null) {
            builder.setOrigin(origin)
            builder.setLocationBias(
                CircularBounds.newInstance(origin, 50_000.0)
            )
        } else {
            builder.setLocationRestriction(
                RectangularBounds.newInstance(
                    LatLng(49.5, -8.8),
                    LatLng(61.0, 2.2)
                )
            )
        }

        return builder.build()
    }

    private fun resolveAutocompleteSessionToken(sessionId: String): AutocompleteSessionToken {
        return autocompleteSessions.getOrPut(sessionId.trim()) {
            AutocompleteSessionToken.newInstance()
        }
    }

    private fun placeToMap(place: Place): Map<String, Any?>? {
        val placeId = place.id?.trim().orEmpty()
        val displayName = place.displayName?.trim().orEmpty()
        val location = place.location

        if (placeId.isEmpty() || displayName.isEmpty() || location == null) {
            return null
        }

        val address = place.formattedAddress?.trim().orEmpty()
        val googleTypes = place.placeTypes
            ?.map { it.lowercase(Locale.UK) }
            ?.distinct()
            .orEmpty()

        return mapOf(
            "placeId" to placeId,
            "displayName" to displayName,
            "address" to address,
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "googleTypes" to googleTypes,
            "mappedPlaceType" to mapParkMateType(
                displayName = displayName,
                address = address,
                googleTypes = googleTypes
            ),
        )
    }

    private fun predictionToMap(
        prediction: AutocompletePrediction
    ): Map<String, Any?>? {
        val placeId = prediction.placeId?.trim().orEmpty()
        val primaryText = prediction.getPrimaryText(null).toString().trim()
        val secondaryText = prediction.getSecondaryText(null).toString().trim()
        val fullText = prediction.getFullText(null).toString().trim()

        if (placeId.isEmpty() || primaryText.isEmpty()) {
            return null
        }

        return mapOf(
            "placeId" to placeId,
            "primaryText" to primaryText,
            "secondaryText" to secondaryText,
            "fullText" to fullText,
        )
    }

    private fun mapParkMateType(
        displayName: String,
        address: String,
        googleTypes: List<String>
    ): String {
        val haystack = "$displayName $address ${googleTypes.joinToString(" ")}"
            .lowercase(Locale.UK)

        return when {
            haystack.contains("truck_stop") || haystack.contains("truck stop") ->
                "Truck Stop"

            haystack.contains("parking") ||
                haystack.contains("parking_lot") ||
                haystack.contains("parking_garage") ->
                "Parking"

            haystack.contains("service_area") ||
                haystack.contains("services") ||
                haystack.contains("rest_stop") ||
                haystack.contains("rest area") ||
                haystack.contains("gas_station") ||
                haystack.contains("fuel") ->
                "Service Area"

            haystack.contains("lay-by") || haystack.contains("layby") ->
                "Lay-by"

            haystack.contains("yard") ->
                "Yard Parking"

            else -> "Other"
        }
    }

    private fun mapPlacesFailure(exception: Exception): Pair<String, String> {
        val rawMessage = exception.message?.trim().orEmpty()

        if (exception is ApiException) {
            if (
                exception.statusCode == CommonStatusCodes.DEVELOPER_ERROR ||
                rawMessage.contains("Places.SearchText", ignoreCase = true) ||
                rawMessage.contains("places.googleapis.com", ignoreCase = true) ||
                rawMessage.contains("are blocked", ignoreCase = true) ||
                rawMessage.contains("REQUEST_DENIED", ignoreCase = true) ||
                rawMessage.contains("not authorized", ignoreCase = true) ||
                rawMessage.contains("API key", ignoreCase = true)
            ) {
                return "places_api_access_denied" to
                    "Google Places is blocked for this Android key. Enable Places API (New) and make sure the Android package name and SHA-1 are allowed."
            }

            if (exception.statusCode == CommonStatusCodes.NETWORK_ERROR) {
                return "places_network_error" to
                    "Google Places could not reach Google right now. Check the connection and try again."
            }
        }

        if (rawMessage.isNotEmpty()) {
            return "places_autocomplete_failed" to rawMessage
        }

        return "places_autocomplete_failed" to
            "Google Places could not search right now."
    }
}
