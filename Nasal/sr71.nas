### Main SR-71 File ###

#Important global variables
MAIN_UPDATE_TIMER = 0.2;
SLOW_UPDATE_TIMER = 0.7;
var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }
var cit_max = 427;
var ab_state = {};
ab_state[0] = 0;
ab_state[1] = 0;

#path locations
var engine_damage = ["/engines/engine[0]/eng-damage","/engines/engine[1]/eng-damage"];
var cit_path = "/fdm/jsbsim/propulsion/cit";
var cit_left = "/engines/engine[0]/cit";
var cit_left_rand_offset = "/engines/engine[0]/cit-rand-offset";
var cit_left_alt_offset = "/engines/engine[0]/cit-alt-offset";
var cit_right = "/engines/engine[1]/cit";
var cit_right_rand_offset = "/engines/engine[1]/cit-rand-offset";
var cit_right_alt_offset = "/engines/engine[1]/cit-alt-offset";

#initial sets
setprop(engine_damage[0],0);
setprop(engine_damage[1],0);
setprop(cit_left_rand_offset,0);
setprop(cit_left_alt_offset,0);
setprop(cit_right_rand_offset,0);
setprop(cit_right_alt_offset,0);

#Fast updating
var main = func () {
	
	#Do CIT stuff.
	cit();
	
	#TEB - if throttle is over 55%, decrement teb. this is where A/B kicks in.
	for ( var i = 0 ; i < 2 ; i = i + 1 ) {
		if ( getprop("/controls/engines/engine["~i~"]/throttle") >= 0.55 and getprop("/instrumentation/teb/display["~i~"]" ) > 0 and ab_state[i] == 0 ) {
			setprop("/instrumentation/teb/display["~i~"]",getprop("/instrumentation/teb/display["~i~"]") - 1);
			ab_state[i] = 1;
		} elsif ( getprop("/controls/engines/engine["~i~"]/throttle") <= 0.55 and ab_state[i] == 1 )  {
			ab_state[i] = 0;
		}
	}
	
	
	# If traveling greater than mach 3.53, unstart the engines.
	if ( getprop("/fdm/jsbsim/velocities/mach") > 3.53 and getprop("/fdm/jsbsim/velocities/mach") < 3.55 ) {
		unstart();
	}
	
	settimer(func { main(); }, MAIN_UPDATE_TIMER);
	
}

var cit = func () {

	# Check CIT, apply randomness, apply temp variation at altitude, split CIT to CIT-right and CIT-left, and calculate damage.
	var cit_temp = getprop(cit_path);
	
	#get random and apply to cit-rand-right and cit-rand-left
	var cit_rand = (rand()/100)-.005;
	setprop(cit_left_rand_offset,clamp(getprop(cit_left_rand_offset) + cit_rand,-10,10));
	cit_rand = (rand()/100)-.005;
	setprop(cit_right_rand_offset,clamp(getprop(cit_right_rand_offset) + cit_rand,-10,10));
	
	#cit atmospheric adjustment.
	#stratospheric temps are modelled badely (they don't fluctuate at all =[). this offsets that a tad.
	#the constant is the amount of degrees fahrenheit per above/below standard at sea level that the altitude cit temp needs to be modded by. it will be +30* at 159*f at sealevel, and -30* at -59*F at sealevel.
	
	if ( (getprop("/position/altitude-ft") != nil) and (getprop("/environment/temperature-sea-level-degc") != nil) ) {
	var cit_temp_offset = (clamp((getprop("/position/altitude-ft") - 65000)/15000,0,1)) * (0.275229358 * (getprop("/environment/temperature-sea-level-degc")-15));
	setprop(cit_left_alt_offset,cit_temp_offset);
	setprop(cit_right_alt_offset,cit_temp_offset);
	}
	
	#now set left/right cit
	setprop(cit_left,getprop(cit_path) + getprop(cit_left_alt_offset) + getprop(cit_left_rand_offset));
	setprop(cit_right,getprop(cit_path) + getprop(cit_right_alt_offset) + getprop(cit_right_rand_offset));
	
	#check for engine damage related to the CIT
	cit_engine_damage(getprop(cit_left),0);
	cit_engine_damage(getprop(cit_right),1);
	
}

var cit_engine_damage = func (cit_temp, eng_num) {
	if ( cit_temp > cit_max ) {
		#need to also add in when IGV is in axial - 150C is maximum - 115C is transition, 125C is maximum allowed
		#mach 1.8
		#want indicator light first though
		
		#calculate how much engine damage this should add
		#going to use linear interpolation for this, sorry.
		#var cit_overheat = cit_temp - cit_max;
		if ( cit_temp < 453 ) {
			var x1 = 428;
			var y1 = 18000 / MAIN_UPDATE_TIMER; # 5 hours at CIT of 428
			var x2 = 453;
			var y2 = 2400 / MAIN_UPDATE_TIMER; # 45 minutes at CIT of 453
		} elsif ( cit_temp < 478 ) {
			var x1 = 453;
			var y1 = 2400 / MAIN_UPDATE_TIMER;
			var x2 = 478;
			var y2 = 300 / MAIN_UPDATE_TIMER; # 5 minutes at CIT of 478
		} elsif ( cit_temp >= 478 ) {
			var x1 = 478;
			var y1 = 300 / MAIN_UPDATE_TIMER;
			var x2 = 510;
			var y2 = 1 / MAIN_UPDATE_TIMER;
		}
		var value_interpolate = y1 + (cit_temp - x1) * ((y2 - y1) / (x2 - x1));
		var damage_actual = 18000 / value_interpolate;
		var damage_percent = damage_actual * ( 1 / 18000 );
		setprop(engine_damage[eng_num],getprop(engine_damage[eng_num]) + damage_percent);
	}

	# startup procedures

	# Disable engines if engine damage > 1. They melted.

	if ( getprop(engine_damage[0]) >= 1 ) {
		setprop("/sim/failure-manager/engines/engine[0]/serviceable",0);
	}

	if ( getprop(engine_damage[1]) >= 1 ) {
		setprop("/sim/failure-manager/engines/engine[1]/serviceable",0);
	}
}

var start_engine = func(v, stage) {
	for ( var i = 0 ; i < 2 ; i = i + 1 ) {
		if ( getprop("sim/input/selected/engine["~i~"]") == 1 ) {
			setprop("/controls/engines/engine["~i~"]/starter",v);
			if ( stage == 2 ) {
				setprop("/fdm/jsbsim/propulsion/engine["~i~"]/teb-shots",getprop("/fdm/jsbsim/propulsion/engine["~i~"]/teb-shots") - 1);
				setprop("/instrumentation/teb/display["~i~"]",getprop("/instrumentation/teb/display["~i~"]") - 1);
			}
		}
	}	
}


var unstart = func() {
	setprop("/fdm/jsbsim/fcs/cutoff-switch0",0);
	setprop("/fdm/jsbsim/fcs/cutoff-switch1",0);
}

#init functions
main();