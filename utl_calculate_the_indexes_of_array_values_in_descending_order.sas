Calculate the indexes of array values in descending order

github
https://gist.github.com/rogerjdeangelis/cf412ebb43b93f1058b746811c72b5be

see
https://communities.sas.com/t5/Base-SAS-Programming/Order-values-in-a-row/m-p/428101


INPUT  Assign indeses that order Have largest to smallest
=========================================================

 SD1.HAVE total obs=2  |  RULES  Order V1-V3 largest to smallest
                       |                                       WANT
    V1    V2    V3     |   O1          O2         O3         O1  O2  O3
                       | Middle      Largest    Lowest
    33    45    21     |  33=2        45=1       21=3         2   1   3
                       |
    13    18    25     |  13=3        18=2       25=1         3   2   1
                       | Smalllest   Middle     Largest
                       |

WORKING CODE
============

   WPS/PROC R

    want<-t(apply(have,1,function(x) rank(-1*x)));

OUTPUT
======

 WORK.WANT total obs=2

    V1    V2    V3    V11    V21    V31

    33    45    21     2      1      3
    13    18    25     3      2      1
*                _              _       _
 _ __ ___   __ _| | _____    __| | __ _| |_ __ _
| '_ ` _ \ / _` | |/ / _ \  / _` |/ _` | __/ _` |
| | | | | | (_| |   <  __/ | (_| | (_| | || (_| |
|_| |_| |_|\__,_|_|\_\___|  \__,_|\__,_|\__\__,_|

;

options validvarname=upcase;
libname sd1 "d:/sd1";
data sd1.have;
  input V1-V3;
cards4;
33 45 21
13 18 25
;;;;
run;quit;

*          _       _   _
 ___  ___ | |_   _| |_(_) ___  _ __
/ __|/ _ \| | | | | __| |/ _ \| '_ \
\__ \ (_) | | |_| | |_| | (_) | | | |
|___/\___/|_|\__,_|\__|_|\___/|_| |_|

;

%utl_submit_wps64('
libname sd1 sas7bdat "d:/sd1";
options set=R_HOME "C:/Program Files/R/R-3.3.2";
libname wrk sas7bdat "%sysfunc(pathname(work))";
libname hlp sas7bdat "C:\Program Files\SASHome\SASFoundation\9.4\core\sashelp";
proc r;
submit;
source("C:/Program Files/R/R-3.3.2/etc/Rprofile.site", echo=T);
library(haven);
have<-read_sas("d:/sd1/have.sas7bdat");
want<-rank(-1*have[1,]);
want<-t(apply(have,1,function(x) rank(-1*x)));
want<-cbind(have,want);
endsubmit;
import r=want data=wrk.want;
run;quit;
');

nteresting. But I find this a bit simpler, let alone wholly within the SAS' means:

data wrk.want (drop = v1-v3) ;
  set sd1.have ;
  array  v  v1-v3 ;
  array  x  v11 v21 v31 ;
  do over v ;
    v = -v * 10 - _i_ ;
  end ;
  call sortN (of v[*]) ;
  do over x ;
    x = mod (-v, 10) ;
  end ;
run ;

FWIW,
Paul Dorfman



Quite correct. Unless, of course, a V-value itself is already at the SAS integer
precision limit. If so, the problem can be easily solved in general simply by
extruding the V-values through an ordered hash:

data wrk.want (keep = v11 v21 v31) ;
  if _n_ = 1 then do ;
    dcl hash h (multidata:"Y", ordered:"D") ;
    h.defineKey ("_v") ;
    h.defineData ("_i_") ;
    h.defineDone() ;
    dcl hiter hi ("h") ;
  end ;
  set sd1.have ;
  array v v: ;
  do over v ;
    _v = v ;
    h.add() ;
  end ;
  array x (_x_) v11 v21 v31 ;
  do _x_ = 1 by 1 while (hi.next() = 0) ;
    x = _i_ ;
  end ;
  h.clear() ;
run ;

Best,
Paul Dorfman


Actually, it can be done even simpler, shorter, and more robustly (the latter in
the sense of the integer precision limit I mentioned in my reply to Mark):

data wrk.want (drop = v1-v3) ;
  set sd1.have ;
  array  v[*] v1-v3 ;
  array  x v11 v21 v31 ;
  do over x ;
    x = whichN (max(of v[*]), of v[*]) ;
    v[x] = ._ ;
  end ;
run ;

However, I suspect from the nature of the algorithm that performance-wise,
it won't scale as well as the other variants as the number of the V's grow,
since in the above method array V is essentially scanned about
1.5 times on the average in every iteration of the DO loop.

Best,
Paul Dorfman



