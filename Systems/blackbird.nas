#Parachute de freinage=========================================


#transféré vers FDM



#Alimentation Electrique========Allumé   Coupé===========================================

#transféré vers FDM



#controle permanent=======================================================


#Cutoff géré globalement par =========jsbsim/fcs/cutoff-switch========voir le FDM
Update_engine=func{ 
                var  cutoff0 =0;
                var  cutoff1 =0;
                if (getprop("/controls/engines/engine[0]/cutoff-cmd")) { cutoff0 =1; }
                if (getprop("/controls/engines/engine[1]/cutoff-cmd")) { cutoff1=1; }
                #==place pour d'autres causes de cutoff======
                setprop("/controls/engines/engine[0]/cutoff",cutoff0);
                setprop("/controls/engines/engine[1]/cutoff",cutoff1);
        }
#==============================================

#==============================================
Loop_update_blackbird=func{
                Update_engine();

                settimer ( Loop_update_blackbird, 2 );
                }
Loop_update_blackbird();
#==============================================

