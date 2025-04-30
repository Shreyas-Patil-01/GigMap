import googlemaps
import folium
import polyline  
import os


API_KEY = os.getenv("API_KEY")
gmaps = googlemaps.Client(key=API_KEY)

locations = [
    "Belagavi RPD circle",
    "Belagavi Bogarves",
    "Belagavi Ganeshpur",
    "Belagavi Kangrali kh"
]

try:
    # Request directions
    directions_result = gmaps.directions(
        locations[0],
        locations[-1],
        waypoints=[loc for loc in locations[1:-1]],
        optimize_waypoints=False,
        mode="driving"
    )

    if directions_result:
        print("Directions Data:")
        for i, leg in enumerate(directions_result[0]['legs']):
            start_address = leg['start_address']
            end_address = leg['end_address']
            distance = leg['distance']['text']
            duration = leg['duration']['text']
            print(f"\nLeg {i+1}:")
            print(f"  Start: {start_address}")
            print(f"  End: {end_address}")
            print(f"  Distance: {distance}")
            print(f"  Duration: {duration}")
            print("  Steps:")
            for step in leg['steps']:
                print(f"    {step['html_instructions']}")

        # Extract coordinates for visualization
        coordinates = []
        if directions_result[0]['legs']:
            coordinates.append(directions_result[0]['legs'][0]['start_location'])
            for leg in directions_result[0]['legs']:
                coordinates.append(leg['end_location'])

            print("\nCoordinates of Locations:")
            for i, coord in enumerate(coordinates):
                label = chr(ord('A') + i)
                print(f"  {label}: Lat: {coord['lat']}, Lng: {coord['lng']}")

            if 'overview_polyline' in directions_result[0]:
                polyline_str = directions_result[0]['overview_polyline']['points']
                print("\nPolyline (for drawing the line on a map):")
                print(polyline_str)

                # Decode polyline to list of lat/lng
                path = polyline.decode(polyline_str)

                # Create a folium map
                start_coords = (coordinates[0]['lat'], coordinates[0]['lng'])
                my_map = folium.Map(location=start_coords, zoom_start=13)

                # Add markers for each location
                offset_lat = 0.0003  # Small vertical offset so label doesn't cover the pin
                offset_lng = 0.0003  # Small horizontal offset

                for i, coord in enumerate(coordinates):
                    label = chr(ord('A') + i)

                    # 1. Add the actual map marker (precise location)
                    folium.Marker(
                        location=(coord['lat'], coord['lng']),
                        icon=folium.Icon(color='red', icon='info-sign'),
                        popup=f"Location {label}"
                    ).add_to(my_map)

                    # 2. Add floating label nearby (slightly offset from the actual pin)
                    folium.map.Marker(
                        location=(coord['lat'] + offset_lat, coord['lng'] + offset_lng),
                        icon=folium.DivIcon(
                            html=f'<div style="font-size: 16pt; color: black;"><b>{label}</b></div>',
                        )
                    ).add_to(my_map)


                # Draw polyline on map
                folium.PolyLine(path, color="red", weight=5, opacity=0.8).add_to(my_map)

                # Save the map
                my_map.save("route_map.html")
                print("\nMap has been saved as 'route_map.html'. Open it in your browser to view the route.")
            else:
                print("\nOverview polyline not found in the results.")
        else:
            print("\nNo legs found in the directions result.")

    else:
        print("No directions found for the given locations.")

except googlemaps.exceptions.ApiError as e:
    print(f"An error occurred: {e}")
