cd G:\Jed\Miscellaneous

/*

Task: Produce counts of injury events and follow-up time,
stratified by: 
time-updated drug use; 
age (0-19, 20-39, 40-59, 60-79, and 80+);
sex;
financial year.

Steps: 
1. Time-updated drug use
2. Admissions
3. Insulin
4. SU

*/

*1 
{
forval i = 1/10 {
use "G:\PBS data\PBS extract `i' slim.dta", clear
keep if substr(atc,1,4)=="A10A"
save insulin_`i', replace
}
clear
forval i = 1/10 {
append using insulin_`i'
}
gen dos = date(date_of_supply,"DMY")
format dos %td
drop pharmacy_p prescriber date_of_p patient_cat atc drug_name
save insworking, replace
use insworking, clear
bysort item : keep if _n==1
expand 2 if _n==1
sort item
keep item
save insitemlist, replace
use insworking, clear
bysort aihw item (dos) : gen dist = dos[_n+1]-dos
levelsof item, local(levels)
mat A = (.,.)
foreach l of local levels {
di "`l'"
su dist if item == "`l'", detail
mat A = (A\r(p75),r(p90))
}
use insitemlist, clear
br
svmat A
drop if A1==.
rename A1 p75
rename A2 p90
save insrefills, replace
*Assumingall switching -- means someone with basal bolus will get major 
*extra time if they're on it for 2-3 dispensing cycles -- but assume they are unlikely to come off that regimen. 
use insworking, clear
merge m:1 item using insrefills
drop _merge
gen cov = dos+p90
format cov %td
forval j = 2/1000 {
bysort aihw (dos) : replace cov = cov+(cov[_n-1]-dos) if ((cov[_n-1]-dos)>0) & _n == `j'
}
bysort aihw (dos) : gen start = 1 if _n == 1
bysort aihw (dos) : gen stop = 1 if _n == _N
bysort aihw (dos) : replace stop = 1 if dos[_n+1] > cov & dos[_n+1]!=.
bysort aihw (dos) : replace start = 1 if stop[_n-1]==1
save temptr, replace
use temptr, clear
keep if start == 1 | stop == 1
gen start_date = dos if start == 1
gen stop_date = cov if stop == 1
format start_date stop_date %td
bysort aihw (dos) : gen dp = 1 if stop==1 & stop[_n-1]==. &start[_n-1]==1
bysort aihw (dos) : replace stop_date = stop_date[_n+1] if dp[_n+1]==1
drop if dp == 1
replace stop_date = . if stop_date > td(31,12,2019)
keep aihw start_date stop_date
save time_updated_insulin, replace


forval i = 1/10 {
use "G:\PBS data\PBS extract `i' slim.dta", clear
keep if substr(atc,1,5)=="A10BB" | atc=="A10BD02"
save SU_`i', replace
}
clear
forval i = 1/10 {
append using SU_`i'
}
gen dos = date(date_of_supply,"DMY")
format dos %td
drop pharmacy_p prescriber date_of_p patient_cat atc drug_name
save suworking, replace
use suworking, clear
bysort item : keep if _n==1
expand 2 if _n==1
sort item
keep item
save suitemlist, replace
use suworking, clear
bysort aihw item (dos) : gen dist = dos[_n+1]-dos
levelsof item, local(levels)
mat A = (.,.)
foreach l of local levels {
di "`l'"
su dist if item == "`l'", detail
mat A = (A\r(p75),r(p90))
}
use suitemlist, clear
br
svmat A
drop if A1==.
rename A1 p75
rename A2 p90
save surefills, replace
*Assumingall switching -- means someone with basal bolus will get major 
*extra time if they're on it for 2-3 dispensing cycles -- but assume they are unlikely to come off that regimen. 
use suworking, clear
merge m:1 item using surefills
drop _merge
gen cov = dos+p90
format cov %td
forval j = 2/1000 {
bysort aihw (dos) : replace cov = cov+(cov[_n-1]-dos) if ((cov[_n-1]-dos)>0) & _n == `j'
}
bysort aihw (dos) : gen start = 1 if _n == 1
bysort aihw (dos) : gen stop = 1 if _n == _N
bysort aihw (dos) : replace stop = 1 if dos[_n+1] > cov & dos[_n+1]!=.
bysort aihw (dos) : replace start = 1 if stop[_n-1]==1
save temptrs, replace
use temptrs, clear
keep if start == 1 | stop == 1
gen start_date = dos if start == 1
gen stop_date = cov if stop == 1
format start_date stop_date %td
bysort aihw (dos) : gen dp = 1 if stop==1 & stop[_n-1]==. &start[_n-1]==1
bysort aihw (dos) : replace stop_date = stop_date[_n+1] if dp[_n+1]==1
drop if dp == 1
replace stop_date = . if stop_date > td(31,12,2019)
keep aihw start_date stop_date
save time_updated_su, replace

use time_updated_su, clear
bysort aihw (start) : gen SUi = _n
ta SUi
forval i = 1/73 {
preserve
keep if SUi == `i'
save SUi_`i', replace
restore
}

forval i = 1/73 {
use SUi_`i', clear
rename start start
rename stop stop
merge 1:m aihw using time_updated_insulin
drop if _merge == 2
drop _merge
save SUiin_`i', replace
}

clear
forval i = 1/73 {
append using SUiin_`i'
}

sort aihw SUi start_date

bysort aihw SUi : gen n=_n
bysort aihw SUi : gen N=_N

/*


Only situation that matters is when insulin overlaps SU time
Possible ways this can occur

1. Insulin before SU and stops during

SU    |-----|
IN |-----|

Means you need to replace SU start date with insulin stop date


2. Insulin before SU and IN goes over


SU    |-----\
IN |------------\

Means you need to totally drop the SU time


3. Insulin after SU

SU |-----\
IN    |-----\

Means you need to replace SU stop time


4. Insulin after SU and SU keeps going

SU |----------\
IN    |-----|

Means you need to replace SU stop time and make a new SU start time

(and a special case where SU finishes on the day insulin starts)

do this then re-aoppend and followup time shoudl be right

*/

preserve
keep if start_date==.
keep aihw start stop 
rename start start_date
rename stop stop_date
save noins, replace
restore

drop if start_date==.

gen nointeraction = 1 if stop_date < start | (start_date>stop)

gen T1 = 1 if start_date<=start & inrange(stop_date,start,stop)

gen T2 = 1 if start_date<=start & (stop_date>stop | (stop==. & stop_date==.))

gen T3 = 1 if (start<start_date) & ((stop_date>=stop) | (stop==. & stop_date==.)) & stop>start_date

gen T4 = 1 if start<start_date & stop_date<stop


*recode nointeraction .=0
*recode T1 .=0
*recode T2 .=0
*recode T3 .=0
*recode T4 .=0

*gen chk = T1+T2+T3+T4+nointeraction
*ta chk


replace start = stop_date+1 if T1 == 1
bysort aihw SUi (n) : egen T2i = min(T2)
drop if T2i == 1
drop T2i
replace stop = start_date-1 if T3==1
gen stop1 = start_date-1 if T4==1
gen start2 = stop_date+1 if T4==1
format stop1 start2 %td
replace stop = stop-1 if stop==start_date & start_date!=.

expand 2 if T4 == 1
bysort aihw SUi n : gen T4n = _n if T4==1
replace stop = stop1 if T4n==1
replace start = start2 if T4n==2

bysort aihw SUi (n) : gen A= 1 if stop[_n+1]<stop
bysort aihw SUi (n) : replace stop = stop[_n+1] if stop[_n+1]<stop
bysort aihw SUi (n) : drop if A[_n-1]==1
drop A
bysort aihw SUi (n) : gen AA = 1 if n!=N & noint==1 & _N!=1
bysort aihw SUi (n) : egen A = sum(noint)
bysort aihw SUi (n) : gen B = 1 if noint==1 & _N!=A

drop if AA==1 | B == 1

keep aihw start stop 
rename start start_date
rename stop stop_date
append using noins
gen SU = 1
append using time_updated_insulin
replace SU = 2 if SU==.
sort aihw start
drop if start_date >= stop_date
save timeupdatedsuin, replace


*Check
use time_updated_su, clear
gen SU = 1
append using time_updated_insulin
replace SU = 2 if SU==.
sort aihw start


}

*2 
{
foreach i in 1011 1112 1213 1314 1415 1516 1617 {
use "G:/Hospital data/extract_`i'.dta", clear
keep if state == "QLD" | state == "VIC"
keep aihw admission_month-separation_year diag1
replace diag1 = substr(diag1,2,5)
gen IJ = 1 if inrange(diag1,"S00","T3599") | inrange(diag1,"T66","T7999")
keep if IJ == 1
save IJ_`i', replace
}
clear
foreach i in 1011 1112 1213 1314 1415 1516 1617 {
append using IJ_`i'
}
gen admid = _n
gen sepday=.
replace sepday = runiformint(1,31) if (separation_month == 1 | separation_month == 3 | separation_month == 5 | separation_month == 7 | separation_month == 8 | separation_month == 10 | separation_month == 12)
replace sepday = runiformint(1,30) if (separation_month == 4 | separation_month == 6 | separation_month == 9 | separation_month == 11)
replace sepday = runiformint(1,28) if separation_month == 2
gen sepdate=mdy(separation_month,sepday,separation_year)
format sepdate %td
save allIJ, replace
}

*3
{

copy "G:\Jed\Hospitalisation inequality\Data\Exitry.dta" Exitry.dta
use "G:\NDSS data\NDSS cleaned.dta", clear
keep if diabetes_type == 2
keep aihw sex diabetes_type_ndss regdate-censdate90 diabetes_type
save NDSS, replace

use NDSS, clear
drop entry
merge 1:1 aihw using Exitry
keep if _merge == 3
drop _merge
drop if dod <= td(1,7,2010) | regdate >= td(30,6,2017) | entry >= td(30,6,2017)

merge 1:m aihw using time_updated_insulin
drop if _merge == 2
drop _merge

bysort aihw (start_date) : gen njm = _n

expand 2 if stop_date!=.

bysort aihw njm : gen njm2 = _n

gen strt = start_date if njm2 == 1
replace strt = stop_date+1 if njm2 == 2
format strt %td

gen stp = stop_date if njm2 == 1
bysort aihw (njm njm2) : replace stp = start_date[_n+1]-1 if njm2==2
format stp %td

gen IN = 1 if njm2 == 1 & start_date!=.

*Reg to insulin
gen FO = 1 if njm == 1 & njm2 == 1 & IN == 1
expand 2 if njm == 1 & njm2 == 1 & IN == 1

bysort aihw (njm njm2) : gen FO2 = 1 if _n == 1 & FO == 1
replace strt=. if FO2==1
replace stp = start_date-1 if FO2 == 1
replace IN =. if FO2==1
drop FO FO2

recode IN .=0
gen enterr = max(regdate,entry,strt,td(1,7,2010))

gen faildate = min(censdate90,dod,stp,exitry,td(30,6,2017))
format enterr faildate %td


drop if enterr >= faildate

gen fail = 0

gen ori = td(1,7,2010)


*stset
gen ppn = _n
stset faildate, fail(fail) enter(enterr) origin(ori) id(ppn) scale(365.25)
stsplit year, at(0(1)7)
stsplit age, at(0(20)80) after(time=dob)
keep aihw sex IN _t _t0 year age 
bysort aihw (_t0) : gen njm = _n
save setset, replace

use setset, clear
ta njm
forval i = 1/31 {
preserve
keep if njm == `i'
save setset_`i', replace
restore
}

forval i = 1/31 {
use setset_`i', clear
merge 1:m aihw using allIJ
keep if _merge == 3
gen sepdate1 = (sepdate-td(1,7,2010))/365.25
keep if inrange(sepdate1,_t0,_t)
keep aihw njm diag1 admid 
save admset_`i', replace
}

clear
forval i = 1/31 {
append using admset_`i'
}
bysort admid : drop if _n == 2
gen IJ = 1
gen HN = 1 if inrange(diag1,"S00","S1999")
gen LE = 1 if inrange(diag1,"S70","S9999") | inrange(diag1,"T13","T14")
gen AT = 1 if inrange(diag1,"S20","S3999")
gen VT = 1 if substr(diag1,1,4)=="S220" | substr(diag1,1,4)=="S221" | substr(diag1,1,3)=="S23" | substr(diag1,1,3)=="S24" | inrange(diag1,"S32","S3499")
gen UE = 1 if inrange(diag1,"S40","S6999")
gen BU = 1 if inrange(diag1,"T20","T3199")
gen OT = 1 if HN==. & LE==. & AT==. & VT==. & UE==. & BU==.
drop diag1 admid
save admset, replace


use setset, clear
merge 1:m aihw njm using admset
drop _merge
gen double py = _t-_t0
bysort aihw njm : replace py = 0 if _n!=1
collapse (sum) IJ-py, by(sex age year IN)
label variable IN "Insulin use"
label variable IJ "All injury count"
label variable HN "Head and neck injury count"
label variable LE "Lower extremity injury count"
label variable AT "Abdominal and thoracic injury count"
label variable VT "Vertebral injury count"
label variable UE "Upper extremity injury count"
label variable BU "Burns injury count"
label variable OT "Other injury count"
label variable py "Person-years of follow-up"

save insulinres, replace

*Check with no insulin
{
use insulinres, clear
collapse (sum) py, by(sex age year)
save noinscheck, replace

use NDSS, clear
drop entry
merge 1:1 aihw using Exitry
keep if _merge == 3
drop _merge
drop if dod <= td(1,7,2010) | regdate >= td(30,6,2017) | entry >= td(30,6,2017)

gen enterr = max(regdate,entry,td(1,7,2010))

gen faildate = min(censdate90,dod,exitry,td(30,6,2017))
format enterr faildate %td


drop if enterr >= faildate

gen fail = 0

gen ori = td(1,7,2010)


*stset
gen ppn = _n
stset faildate, fail(fail) enter(enterr) origin(ori) id(aihw) scale(365.25)
stsplit year, at(0(1)7)
stsplit age, at(0(20)80) after(time=dob)
gen double py = _t-_t0
collapse (sum) py, by(sex age year)
rename py py2
merge 1:1 sex age year using noinscheck
gen chk = py-py2
}





}

*4
{


use NDSS, clear


 drop entry
merge 1:1 aihw using Exitry
keep if _merge == 3
drop _merge
drop if dod <= td(1,7,2010) | regdate >= td(30,6,2017) | entry >= td(30,6,2017)

merge 1:m aihw using timeupdatedsuin
drop if _merge == 2
drop _merge

bysort aihw (start_date) : gen njm = _n

expand 2 if stop_date!=.

bysort aihw njm : gen njm2 = _n

gen strt = start_date if njm2 == 1
replace strt = stop_date+1 if njm2 == 2
format strt %td

gen stp = stop_date if njm2 == 1
bysort aihw (njm njm2) : replace stp = start_date[_n+1]-1 if njm2==2
format stp %td

replace SU = . if njm2 == 2


*Reg to drug
gen FO = 1 if njm == 1 & njm2 == 1 & SU!=.
expand 2 if njm == 1 & njm2 == 1 & SU!=.

bysort aihw (njm njm2) : gen FO2 = 1 if _n == 1 & FO == 1
replace strt=. if FO2==1
replace stp = start_date-1 if FO2 == 1
replace SU =. if FO2==1
drop FO FO2

recode SU .=0
gen enterr = max(regdate,entry,strt,td(1,7,2010))

gen faildate = min(censdate90,dod,stp,exitry,td(30,6,2017))
format enterr faildate %td


drop if enterr >= faildate

gen fail = 0

gen ori = td(1,7,2010)


*stset
gen ppn = _n
stset faildate, fail(fail) enter(enterr) origin(ori) id(ppn) scale(365.25)
save chekkkh, replace
stsplit year, at(0(1)7)
stsplit age, at(0(20)80) after(time=dob)
keep aihw sex SU _t _t0 year age 
bysort aihw (_t0) : gen njm = _n
save setsetsu, replace





use setsetsu, clear
ta njm
forval i = 1/74 {
preserve
keep if njm == `i'
save setsetsu_`i', replace
restore
}

forval i = 1/74 {
use setsetsu_`i', clear
merge 1:m aihw using allIJ
keep if _merge == 3
gen sepdate1 = (sepdate-td(1,7,2010))/365.25
keep if inrange(sepdate1,_t0,_t)
keep aihw njm diag1 admid 
save admsetsu_`i', replace
}

clear
forval i = 1/74 {
append using admsetsu_`i'
}
bysort admid : drop if _n == 2
gen IJ = 1
gen HN = 1 if inrange(diag1,"S00","S1999")
gen LE = 1 if inrange(diag1,"S70","S9999") | inrange(diag1,"T13","T14")
gen AT = 1 if inrange(diag1,"S20","S3999")
gen VT = 1 if substr(diag1,1,4)=="S220" | substr(diag1,1,4)=="S221" | substr(diag1,1,3)=="S23" | substr(diag1,1,3)=="S24" | inrange(diag1,"S32","S3499")
gen UE = 1 if inrange(diag1,"S40","S6999")
gen BU = 1 if inrange(diag1,"T20","T3199")
gen OT = 1 if HN==. & LE==. & AT==. & VT==. & UE==. & BU==.
drop diag1 admid
save admsetsu, replace


use setsetsu, clear
merge 1:m aihw njm using admsetsu
drop _merge
gen double py = _t-_t0
bysort aihw njm : replace py = 0 if _n!=1
collapse (sum) IJ-py, by(sex age year SU)
drop if SU == 2
label variable SU "Sulfonylurea use"
label variable IJ "All injury count"
label variable HN "Head and neck injury count"
label variable LE "Lower extremity injury count"
label variable AT "Abdominal and thoracic injury count"
label variable VT "Vertebral injury count"
label variable UE "Upper extremity injury count"
label variable BU "Burns injury count"
label variable OT "Other injury count"
label variable py "Person-years of follow-up"
save sulfonylureares, replace

*Check with no su
{
use sures, clear
collapse (sum) py, by(sex age year)
save nosucheck, replace

use NDSS, clear
drop entry
merge 1:1 aihw using Exitry
keep if _merge == 3
drop _merge
drop if dod <= td(1,7,2010) | regdate >= td(30,6,2017) | entry >= td(30,6,2017)

gen enterr = max(regdate,entry,td(1,7,2010))

gen faildate = min(censdate90,dod,exitry,td(30,6,2017))
format enterr faildate %td


drop if enterr >= faildate

gen fail = 0

gen ori = td(1,7,2010)


*stset
gen ppn = _n
stset faildate, fail(fail) enter(enterr) origin(ori) id(aihw) scale(365.25)
stsplit year, at(0(1)7)
stsplit age, at(0(20)80) after(time=dob)
gen double py = _t-_t0
collapse (sum) py, by(sex age year)
rename py py2
merge 1:1 sex age year using nosucheck
gen chk = py-py2
*Acceptable level of error
}
}

