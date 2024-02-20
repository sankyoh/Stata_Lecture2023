# 予測の続き
前回ひ引き続き、統計学的手法を用いた予測の続きを行います。

なお、予測を上手く使う事で因果を推定することも可能です。最終的にはこれを目指します。この「予測を用いて、因果関係を推定する」というコンセプトは、[Causal Inference for The Brave and True](https://matheusfacure.github.io/python-causality-handbook/landing-page.html)に影響を受けています。

## 前回のおさらい
予測モデルを構築するための学習データと、その予測性能をみるための検証データに分割しました（分割には、`splitsample`コマンドを利用しました）。

予測性能を検証データでみたところ、次の様なキャリブレーションプロットになりました。

```
twoway ///
  (scatter bw_pred_reg2 bweight if svar==1 , mcolor(blue%15)) ///
  (scatter bw_pred_reg1 bweight if svar==1 , mcolor(cranberry%15)) ///
  (function y=x, range(0 5000) lcolor(navy)), ///
  legend(label(1 "273vars") label(2 "3vars") label(3 "y=x"))
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/ee079027-180e-40e5-8efa-674e2fdb247e)

横軸が観察値で縦軸が予測値になるようにプロットしています。このキャリブレーションプロットを見ると一目瞭然ですが、273変数モデルではいくつかの点で予測値が負数になっています。過学習のためこのようなことが起きてしまいます。

一方で、3変数モデルは実測値にかかわらず予測値にブレがありません。これはこれで予測に役立っているようには見えません。

## 今回の話

Stataでどのように予測性能を上げて行く方法があるか、いくつか紹介していきます。

# 機械的な変数選択の方法

機械的な変数選択の方法として、

## 準備

まず、データの読込みと分割を行います。

```
use https://www.stata-press.com/data/r18/cattaneo2, clear
splitsample, generate(svar, replace) split(0.2 0.8) show rseed(12345)
```

前回までと同様に、全ての予測変数、その二乗項、交互作用項を用意します。

```
vl set
vl create xcate = (mmarried mhisp fhisp foreign alcohol deadkids msmoke mbsmoke mrace frace prenatal fbaby prenatal1 order birthmonth)
vl create xcont = (monthslb mage medu fage fedu nprenatal)
vl substitute predvars1 = c.xcont##c.xcont
vl substitute predvars2 = i.xcate##i.xcate
vl substitute predvars3 = i.xcate#c.xcont
```

## ステップワイズ法による変数選択

### BACKWARD
フルモデルからはじめ、そこから基準となるp値に満たない変数を減らしていくという方法です。

Stataでは`stepwise`コマンドが用意されています。このコマンドは、`bysort`などと同様で接頭辞コマンドとして利用します。

```
stepwise, pr(0.2): regress bweight $predvars1 $predvars2 $predvars3 if svar==2
predict bw_pred_bkst, xb
predict resi_pred_bkst, residual
```

一行目の`regress`コマンドの前にstepwiseコマンドを入れています。`pr(0.2)`の0.2が基準となるp値です。また、前回同様に`if svar==2`を入れることによって、学習データのみで`regress`コマンドを実行していることに注意して下さい。

実行にはそれなりに時間がかかりますが下記の様に表示されます（一部分）。p値が大きい変数が除外されています。

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/50fef723-304b-484f-be90-3a7c5e63e752)

最終的に基準を満たすような変数にみが残ります。

`predict`コマンドで予測値などを算出しているので、それらを元にRMSEとRMSPEを算出します。

```
gen resisq_pred_bkst  = resi_pred_bkst * resi_pred_bkst if svar==1
gen resisq_pred_bkstp =  (resi_pred_bkst / bweight)^2   if svar==1

su resisq_pred_bkst if svar==1
local rmse = sqrt(`r(mean)')

su resisq_pred_bkstp if svar==1
local rmspe = sqrt(`r(mean)')

di `rmse'
di `rmspe'
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/332b5c6e-25be-47b4-8700-c7dbf6219276)

RMSE=658.8、RMSPE=0.383でした。

前回の273変数を全部入れたモデル（RMSE=970.9、RMSPE=0.434）と比べるとだいぶんましですが、3変数モデル（RMSE=591.8、RMSPE=0.462）と比べると良い勝負です。計算時間を要した分のメリットは享受できていません。

### FORWARD
ヌルモデルからはじめ、そこから基準となるp値を超える変数を加えていくという方法です。

BACKWARDと同様に`stepwise`コマンドを利用しますが、オプションが`pr`ではなく`pe`になっています。

```
stepwise, pe(0.2): regress bweight $predvars1 $predvars2 $predvars3 if svar==2
predict bw_pred_frst, xb
predict resi_pred_frst, residual
```

一行目の`regress`コマンドの前にstepwiseコマンドを入れています。`pe(0.2)`の0.2が基準となるp値です。また、前回同様に`if svar==2`を入れることによって、学習データのみで`regress`コマンドを実行していることに注意して下さい。

実行にはそれなりに時間がかかりますが下記の様に表示されます（一部分）。p値が小さい変数が追加されています。

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/0f660fd6-ffba-4007-8e48-d61dacbbcdc3)


最終的に基準を満たすような変数にみが残ります。

`predict`コマンドで予測値などを算出しているので、それらを元にRMSEとRMSPEを算出します。

```
gen resisq_pred_frst  = resi_pred_frst * resi_pred_frst if svar==1
gen resisq_pred_frstp =  (resi_pred_bkst / bweight)^2   if svar==1

su resisq_pred_frst if svar==1
local rmse = sqrt(`r(mean)')

su resisq_pred_frstp if svar==1
local rmspe = sqrt(`r(mean)')

di `rmse'
di `rmspe'
```
![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/2748fb11-cc1d-4e81-a701-d015502d3e04)

RMSE=579.7、RMSPE=0.383でした。

BACKWARDと良い勝負です（つまり、3変数モデルと良い勝負）。計算時間を要した分のメリットは享受できていません。

## ステップワイズ法による予測のキャリブレーションプロット

```
twoway ///
  (scatter bw_pred_bkst bweight if svar==1 , mcolor(blue%15)) ///
  (scatter bw_pred_frst bweight if svar==1 , mcolor(cranberry%15)) ///
  (function y=x, range(0 5000) lcolor(navy)), ///
  legend(label(1 "BK stepwise") label(2 "FR stepwise") label(3 "y=x"))
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/ae2cff14-438f-4e9e-9990-eb4bcc697cbf)

FRでは、負数の予測はないものの、だいたい3000g付近を予測しています。この特徴は3変数モデルと同様でした。

平均的な値を予測は可能なものの、個別の予測にはあまり当てにならない、というような結果です。

BKでは、負数の予測をしていて、過学習があると考えられます。

### もし改善するとしたら、
p値の基準を0.2に置いていましたが、これをさらに小さい数値にするという方法が考えられます。

## LASSO回帰

次にLASSO回帰による変数選択を行ってみます。LASSO回帰という言葉は、本講義でも初出かもしれません。

Lasso回帰は数値データに対して、線形回帰を行う手法の一つですが、通常の線形回帰とは異なる方法を用いて回帰係数を計算します。

通常の線形回帰分析は、次のMSEを最小にするような回帰係数を求めています（これは行列計算で行われています）。

$$MSE=\frac{1}{n}\sum_{k=1}^n(y_k-\hat{y_k})^2$$

つまり、実測値と回帰式から予測される値との差の二乗の平均値が最小になるように回帰係数が計算されます。

対して、LASSO回帰では**正則化項**という名前の項が追加されます。βは回帰係数です。

$$ ||β||\_1 \equiv \sum_{i=1}^p|β_i| $$

この**正則化項**は回帰係数の絶対値の総和を表しています。このタイプの正則化項を**L1ノルム**と呼びます。

LASSO回帰では、MSEではなく、**MSEとλ倍したL1ノルムの和**を最小化するようなβを計算します。λはハイパーパラメータで、正則化の強さを制御します。

$$ MSE + λ||β||\_1 $$

### StataでのLASSO回帰の実装

```
lasso linear bweight $predvars1 $predvars2 $predvars3 if svar==2
predict bw_pred_lasso
gen resi_pred_lasso = bweight - bw_pred_lasso
```

なお、λについてはStataが交差検証を行いながら、最もよくなる値を検索してくれます。

今回は、λ = 20.15725が最良だったようです。

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/5a6d096e-4178-4352-95fa-92e446bd6d80)

ここで得られた推定値を元に、RMSEとRMSPEを算出します。

なお、`lasso`コマンドの後では、`predict, residual`ができないため、引き算で残差を求めています。

```
gen resisq_pred_lasso  = resi_pred_lasso * resi_pred_lasso if svar==1
gen resisq_pred_lassop =  (resi_pred_lasso / bweight)^2   if svar==1

su resisq_pred_lasso if svar==1
local rmse = sqrt(`r(mean)')

su resisq_pred_lassop if svar==1
local rmspe = sqrt(`r(mean)')

di `rmse'
di `rmspe'
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/db8adc26-11e2-4867-bce9-d5a0733342a4)

LASSO回帰により変数選択を行いましたが、性能はそこまでよくありません。

RMSE=566.6、RMSPE=0.419でした。

## ランダムフォレスト回帰

過学習を起こしやすいという決定木分析の欠点を、アンサンブル学習によって補うランダムフォレストを行ってみます。

詳しい説明はここでは省略しますが、少しずつ条件を変えた決定木分析を複数回行い、その結果の多数決を取ったり（クラス分類）、平均値を取ったりします（連続量）。

Stataでは標準での実行はできないため、外部コマンドをインストールします。

```
ssc install rforest
```

この`rforest`コマンドには、ランダムフォレストを行う上での条件設定（ハイパーパラメータ）をオプションで設定できますが、標準で問題になることは余り無いように思います。今回も標準で実行します。

なお、予測変数に、`c.`や`i.`や`#`が使えないという制約があるため、これまでの解析とはことなって説明変数には二乗項や交互作用項は含められません。

```
rforest bweight $xcate $xcont if svar==2, type(reg)
predict bw_pred_rforest
gen resi_pred_rforest = bweight - bw_pred_rforest
```

ほとんど時間をおかずに解析が完了しました。

なお、`lasso`コマンドの後では、`predict, residual`ができないため、引き算で残差を求めています。

```
gen resisq_pred_rforest  = resi_pred_rforest * resi_pred_rforest if svar==1
gen resisq_pred_rforestp =  (resi_pred_rforest / bweight)^2   if svar==1

su resisq_pred_rforest if svar==1
local rmse = sqrt(`r(mean)')

su resisq_pred_rforestp if svar==1
local rmspe = sqrt(`r(mean)')

di `rmse'
di `rmspe'
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/ea252872-d188-4c41-9b89-8dddc2cbcbce)

RMSE=473.9、RMSPE=0.267でした。ここまでで一番良い成績になっています。

しかも、計算時間もかなり短かったです。

## LASSOとランダムフォレストのキャリブレーションプロット

```
twoway ///
  (scatter bw_pred_lasso bweight if svar==1 , mcolor(blue%15)) ///
  (scatter bw_pred_rforest bweight if svar==1 , mcolor(cranberry%15)) ///
  (function y=x, range(0 5000) lcolor(navy)), ///
  legend(label(1 "LASSO") label(2 "Random Forest") label(3 "y=x"))
```
![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/a6823097-72eb-4580-a50f-38676d12bd32)

ランダムフォレストでは、だいぶん、対角線（y=x）に近い値が推定されていることが分かります。

# まとめ

このデータでは、ランダムフォレストによる予測が最も制度が良さそうです。

|モデル|RMSE|RMSPE|
|----|----|----|
|3変数モデル|591.8|0.462|
|273変数モデル|970.9|0.435|
|Backwardステップワイズ|658.8|0.383|
|Forwardステップワイズ|579.7|0.383|
|LASSO回帰|566.6|0.419|
|ランダムフォレスト|473.9|0.267|


次回は、この予測を用いた因果推論について説明します。




