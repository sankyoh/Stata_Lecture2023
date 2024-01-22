set seed 12345
local samh = 54 // サンプルサイズ候補・片群
local n    = 1000 // シミュレーション回数
local mu0  = 1.3 // 対照群の平均値
local sd0  = 1.0 // 対照群の標準偏差
local mu1  = 2.0 // 介入群の平均値
local sd1  = 1.5 // 介入群の標準偏差
local a    = 0.05

local smps = `samh'*2 // サンプルサイズ候補・両群
capture frame change default

/*****
Result tabel
*****/
capture frame create results
frame change results
	clear
	set obs `n'
	gen pv  = .
	gen pow = .
frame change default

	/*****
	Simulation
	*****/
	forvalues i=1/`n'{
		qui{
		clear
		set obs `smps'
		gen     x = 0 in 1/`samh'
		replace x = 1 if x==.
		gen     r = rnormal(`mu0', `sd0') if x==0
		replace r = rnormal(`mu1', `sd1') if x==1
		ttest r, by(x) welch
		}
		
	/*****
	Contain results
	*****/
		frame change results
			qui{
			replace pv  = r(p) in `i'
			replace pow = 1 if pv <  `a' in `i'
			replace pow = 0 if pv >= `a' in `i'
			}
		frame change default
	}

/*****
View results
*****/
frame change results
sum	

