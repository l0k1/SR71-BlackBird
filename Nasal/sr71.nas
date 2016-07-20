### Main SR-71 File ###

#Important global variables
MAIN_UPDATE_TIMER = 0.3;
SLOW_UPDATE_TIMER = 0.7;

#path locations
var engine_damage = ["/engines/engine[0]/eng-damage","/engines/engine[1]/eng-damage"];
var cit_path = "/fdm/jsbsim/propulsion/cit";

#initial sets
setprop(engine_damage[0],0);
setprop(engine_damage[1],0);

#Fast updating
var main = func () {
	
	# Check CIT and calculate damage.
	var cit_temp = getprop(cit_path);
	
	#need to also add in when IGV is in axial - 150C is maximum - 115C is transition, 125C is maximum allowed
	#mach 1.8
	#want indicator light first though
	var cit_max = 427;
	if ( cit_temp > cit_max ) {                # 427 is the cutoff - giving 10* as a safety net
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
		setprop(engine_damage[0],getprop(engine_damage[0]) + damage_percent);
		setprop(engine_damage[1],getprop(engine_damage[1]) + damage_percent);
	}
	
	# Disable engines if engine damage > 1. They melted.
	
	if ( getprop(engine_damage[0]) >= 1 ) {
		setprop("/sim/failure-manager/engines/engine[0]/serviceable",0);
	}
	
	if ( getprop(engine_damage[1]) >= 1 ) {
		setprop("/sim/failure-manager/engines/engine[1]/serviceable",0);
	}
	
	# If traveling greater than mach 3.53, unstart the engines.
	
	if ( getprop("/fdm/jsbsim/velocities/mach") > 3.53 and getprop("/fdm/jsbsim/velocities/mach") < 3.55 ) {
		unstart();
	}
	
	settimer(func { main(); }, MAIN_UPDATE_TIMER);
	
}

var unstart = func() {
	setprop("/fdm/jsbsim/fcs/cutoff-switch0",0);
	setprop("/fdm/jsbsim/fcs/cutoff-switch1",0);
}

#init functions
main();