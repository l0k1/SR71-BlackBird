#outputs le sensor (radar, optical) data to an xml file for later viewing.
#full sensor suite infcludes two hi-res narrow field cameras (TECH), ASARS, SLR, ELINT, and OBC (4-79)
#the nose could hold either the side-looking radar (SLR)(4-86) or optical bar camera (OBC)(4-93)
#the blackbird could also capture the recorder correlator display (RCD)(4-90) - not supported at this time.
#Also, the ASARS. if i had any idea how it worked (other than being an f'ing awesome SAR), i'd implement it.

#only doing a bad version of OBC or SLR for now.

#a note on gps precision
#8 - ~.001m (ASARS)
#7 = ~.01m
#6 decimal places = ~.1m (SLR)
#5 = 1m (OBC)
#4 = 10m (TECH)
#3 = 110m
#2 = 1,110m
#1 = 11,110m

#sensor gui dialog
var sensors_dialog = gui.Dialog.new("sensors_dialog/dialog","Aircraft/SR71-BlackBird/Dialogs/sensor_interface.xml");

#logging control
var log_count = props.globals.getNode("/controls/sensors/log-count");
var ready_write = props.globals.getNode("/controls/sensors/ready-write");

### OBC ###
#per SR-71 manual, the OBC had ~2000 exposures and would normally use one per 1.75 seconds. this is roughly the same time allowance.
#using 10 seconds and 350 exposures to not inundate the average FG player with data.
#may add an option to select rate at a later date.
#obc could look 8* along flight path and 70* on each side

var obc_output_rate = props.globals.getNode("/controls/sensors/obc_output_rate");
var obc_exposures = props.globals.getNode("/controls/sensors/obc-exposures-remaining");

### SLR ###
#the SLR film was measured in NM, not in exposures.
#average NM was 4000 (max on instrument was 4999).
#every 5nm is approx. 2.5 seconds, so this won't capture as much as the OBC (grand total)
#slr could look at an area 10 or 20nm wide, starting from 10 to 70nm to the left or the right of the plane.
var slr_output_rate = props.globals.getNode("/controls/sensors/slr/output-rate");
var slr_exposures = props.globals.getNode("/controls/sensors/slr/exposures-remaining");
var slr_mode = props.globals.getNode("/controls/sensors/slr/mode"); #manual, automatic
var slr_state = props.globals.getNode("/controls/sensors/slr/operate"); #cold, warming, standby, operating, cooling
var slr_start_range = props.globals.getNode("/controls/sensors/slr/start-range"); #10 - 70, intervals of 5
var slr_side = props.globals.getNode("/controls/sensors/slr/side"); #left, right
var slr_width = props.globals.getNode("/controls/sensors/slr/width"); #narrow, wide


#to help give offset/balance, the OBC will only record GPS coords, whereas the SLR will also record altitude and speed (if narrow).
var mode = "/controls/sensors/mode";
var slr = "SLR";
var obc = "OBC";

#find i/o file location
var output_file = getprop("/sim/fg-home") ~ "/Export/SR-71/sensor_output_" ~ getprop("/sim/time/gmt") ~ ".xml";

#if switch is on, output mp data at set intervals.

var sensor_loop = func() {
	###########i'm going to force SLR for now.###############
	
	#exit if not recording.
	if ( getprop("/controls/sensors/recording") == 0 ) { return; }
	
	#basically, if the SR-71 can see it and it's in a 10/20nm wide path, it'll be picked up on this.
	#sr-71 needs to be level and not on ground
	
	var my_pos = geo.aircraft_position();
	
	if ( ( getprop("gear/gear[0]/wow") == 0 and getprop("gear/gear[1]/wow") == 0 and getprop("gear/gear[2]/wow") == 0 and math.abs(getprop("/orientation/pitch-deg")) < 5 and math.abs(getprop("/orientation/roll-deg")) < 5 ) ) {
		#print("reccing!");
		var my_heading = props.globals.getNode("orientation/heading-deg").getValue();
		if ( slr_side.getValue() == "left" ) {
			var radar_heading = angle_normalize(my_heading - 90);
		} else {
			var radar_heading = angle_normalize(my_heading + 90);
		}
		
		foreach(var mp; props.globals.getNode("/ai/models").getChildren("multiplayer")) {
			capture_tgt(mp, my_pos, radar_heading);
		}

		foreach(var mp; props.globals.getNode("/ai/models").getChildren("tanker")){
			capture_tgt(mp, my_pos, radar_heading);
		}

		foreach(var mp; props.globals.getNode("/ai/models").getChildren("ship")){
			capture_tgt(mp, my_pos, radar_heading);
		}

		foreach(var mp; props.globals.getNode("/ai/models").getChildren("groundvehicle")){
			capture_tgt(mp, my_pos, radar_heading);
		}
		foreach(var mp; props.globals.getNode("/ai/models").getChildren("aircraft")){
			capture_tgt(mp, my_pos, radar_heading);
		}
		foreach(var mp; props.globals.getNode("/ai/models").getChildren("carrier")){
			capture_tgt(mp, my_pos, radar_heading);
		}

		slr_exposures.setValue( slr_exposures.getValue() - 1 );
	}
	
	#because SLR loop is distance based, not time based, we need to compare current location to location found at the start of the function, then call this function back
	#looping logic goes here.
	if ( getprop(mode) == slr and slr_exposures.getValue() >= 0 ) {
		distance_wait(slr_output_rate.getValue(), my_pos);
	} elsif ( getprop(mode) == obc and obc_exposures.getValue() > 0 ) {
		settimer(sensor_loop, obc_output_rate.getValue());
	}
}

var capture_tgt = func(mp, my_pos, radar_heading) {
	if ( radar_logic.isNotBehindTerrain(mp) == 1 ) { # can be seen, is good
		var target_lat = mp.getNode("position/latitude-deg").getValue();
		var target_lon = mp.getNode("position/longitude-deg").getValue();
		var target_alt = (mp.getNode("position/altitude-ft").getValue() * FT2M);
		var target_geo = geo.Coord.new().set_latlon(target_lat, target_lon, target_alt);
		var target_callsign = mp.getNode("callsign").getValue();
		if (target_callsign == nil or target_callsign == "") {
			return;
		}
		if (mp.getNode("sim/model/path") == nil or mp.getNode("sim/model/path") == "") {
			var target_airframe = "unknown";
		}else{
			var target_airframe = split(".",split("/",mp.getNode("sim/model/path").getValue())[-1])[0];
		}
		var target_distance = my_pos.direct_distance_to(target_geo) * M2NM; #in nautical miles
		var target_bearing = my_pos.course_to(target_geo);
		var target_airspeed = mp.getNode("velocities/true-airspeed-kt").getValue();
		var target_radar_bearing = target_bearing - radar_heading; #gives angle between contact and radar
		if ( getprop(mode) == slr ) {
			var dist_from_path = math.sin(target_radar_bearing) * target_distance; #gives how far the target is from a line extending left/right from the plane (used for radar width)
			if ( slr_width.getValue() == "narrow" and math.abs(dist_from_path) <= 5 ) {
				target_lat = sprintf("%0.6f",target_lat);
				target_lon = sprintf("%0.6f",target_lon);
				target_alt = math.round(target_alt,10);
				target_airspeed = math.round(target_airspeed,10);
				#print("dist_from_path for " ~ target_callsign ~ ": " ~ dist_from_path);
				#print("radar_bearing for " ~ target_callsign ~ ": " ~ target_radar_bearing);
				#print("target_distance for " ~ target_callsign ~ ": " ~ target_distance);
				write_log(getprop("/sim/time/gmt") ~ "|" ~ getprop(mode) ~ "|TGT:" ~ target_airframe ~ "|CS:" ~ target_callsign ~ "|LAT:" ~ target_lat ~ "|LON:" ~ target_lon ~ "|ALT:" ~ target_alt ~ "|SPD:" ~ target_airspeed);
			} elsif ( slr_width.getValue() == "wide" and math.abs(dist_from_path) <= 10 ) {
				target_lat = sprintf("%0.5f",target_lat);
				target_lon = sprintf("%0.5f",target_lon);
				target_alt = math.round(target_alt,100);
				target_airspeed = math.round(target_airspeed,10);
				#print("dist_from_path for " ~ target_callsign ~ ": " ~ dist_from_path);
				#print("radar_bearing for " ~ target_callsign ~ ": " ~ target_radar_bearing);
				#print("target_distance for " ~ target_callsign ~ ": " ~ target_distance);
				target_alt = sprintf("%0.3f",target_alt);
				write_log(getprop("/sim/time/gmt") ~ "|" ~ getprop(mode) ~ "|TGT:" ~ target_airframe ~ "|CS:" ~ target_callsign ~ "|LAT:" ~ target_lat ~ "|LON:" ~ target_lon ~ "|ALT:" ~ target_alt);
			}
		}
	}
}

var distance_wait = func(rate, old_pos) {
	var new_pos = geo.aircraft_position();
	var dt = new_pos.direct_distance_to(old_pos) * M2NM;
	if ( dt >= rate ) {
		sensor_loop();
	} else {
		settimer( func { distance_wait(rate,old_pos); },0.3);
	}
	#settimer(sensor_loop,1);
}

var log_out_full = "test";
var log_count = 1;
var ready_write = 0;

var write_log = func(message) {
	log_out_full = log_out_full ~ "\n" ~ log_count ~ "|" ~ message;
	log_count = log_count + 1;
	ready_write = 1
}

var output_log = func(override = 0) {
	if ( override == 0 and (getprop("/position/altitude-agl-ft") > 40 or ready_write == 0)) {
		return; 
	}
	if ( override == 1 or (getprop("/gear/gear[0]/wow") == 1 and getprop("/gear/gear[1]/wow") == 1 and getprop("/gear/gear[2]/wow") == 1 and getprop("/velocities/groundspeed-kt") < 5  and ready_write == 1) ) {		
		var timestamp = getprop("/sim/time/real/minute") ~ "-" ~ getprop("/sim/time/real/hour") ~ "-" ~ getprop("/sim/time/real/day") ~ "-" ~ getprop("/sim/time/real/month") ~ "-" ~ getprop("/sim/time/real/year");
		var output_file = getprop("/sim/fg-home") ~ "/Export/SR-71_sensor_output_" ~ timestamp ~ ".txt";
		print(output_file);
		var file = io.open(output_file, "w+"); # open in write mode
		io.write(file, log_out_full); # write the data
		io.close(file); # close (and flush) the file stream
		ready_write = 0;
	} else {
		settimer(output_log,1);
	}
}

var angle_normalize = func (angle) {
	if ( angle < 0 ) {
		angle = angle + 360;
	} elsif ( angle > 360 ) {
		angle = angle - 360;
	}
	return angle;
}

#start recording
setlistener("/controls/sensors/recording", func { sensor_loop(); } );
setlistener("/gear/gear[0]/wow", func { output_log(); } );
