# 予測の続き
前回ひ引き続き、統計学的手法を用いた予測の続きを行います。

なお、予測を上手く使う事で因果を推定することも可能です。最終的にはこれを目指します。この「予測を用いて、因果関係を推定する」というコンセプトは、[Causal Inference for The Brave and True](https://matheusfacure.github.io/python-causality-handbook/landing-page.html)に影響を受けています。

## 前回のおさらい
線形回帰分析（`regress`）を用いて、アウトカムの予測を用いました。

まずは、2つのモデルを採用しました。
* 予測変数として、3変数のみを用いる。
* 予測変数として、2次項や交互作用項も含めて、273変数を用いる。

この予測精度をRMSEやRMSPEで比較しました。3変数よりも273変数の方が、よい予測精度になっていました。

ただし、キャリブレーションプロットでは、そこまで「良い」とまでは言えませんでした。

```
twoway ///
  (scatter bw_pred_reg2 bweight , mcolor(blue%15)) ///
  (scatter bw_pred_reg1 bweight , mcolor(cranberry%15)) ///
  (function y=x, range(0 5000) lcolor(navy)), ///
  legend(label(1 "273vars") label(2 "3vars") label(3 "y=x"))
```

![Graph](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/8894e771-8ad7-492a-99f8-df359be9ce64)

横軸が観察値で縦軸が予測値です。赤いプロットが最初の予測によるプロットですが、かなり駄目なのがわかります。一方で、青いプロットが今行った273個の変数を用いたプロットです。改善があるものの駄目な感じがわかります。

## 前回の言い残したこと。

「このようなやり方が良く無い理由と多重共線性を気にしていない理由などを含めて、改善していきます。」

# 予測を行う
## サンプルデータ
サンプルデータを用いて、アウトカムの予測を行います（正確には、予測可能な統計モデルを作成します）。

利用するサンプルデータは、引き続き「cattaneo2」です。

```
use https://www.stata-press.com/data/r18/cattaneo2, clear
```

今回も、出生前の変数を用いて、出生児の体重の予測を行います。

ここでは用語を次の様に定義します。
* アウトカム変数・応答変数 = 予測される変数（ここでは、出生児体重）
* 説明変数・予測変数 = 予測をするために用いる変数（ここでは、母親の年齢など）

# 多重共線性を気にしない理由
まず、**多重共線性**を気にしていない理由から説明します。

多重共線性とは「重回帰モデルにおいて、説明変数の中に、相関係数が高い組み合わせがあること」（[Wikipedia](https://ja.wikipedia.org/wiki/%E5%A4%9A%E9%87%8D%E5%85%B1%E7%B7%9A%E6%80%A7)）です。これによって、重回帰分析では、回帰係数が不安定になります。

百聞は一見にしかず、といいますので、早速試してみましょう。

## 多重共線性がある線形回帰モデル
実験用に、多重共線性が問題になる`tmp`という変数をわざと作ります。

```
set seed 12345
gen tmp = mage - medu + runiform(1,2)
```

`mage`（母親の年齢）から`medu`（母親の教育年数）を引いていますので、`tmp`は教育を受けていない年数に相当します。そこに`runiform(1,2)`を足しています。少し値をブレさせないと回帰分析の結果がomitされるためです。

回帰分析を実行し、VIFを計算します。

```
regress bweight mbsmoke mage medu tmp
estat vif
predict xb1
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/e6752398-ffb6-4c72-9ec2-e08f71a96698)

当たり前ですが、`mage`と`tmp`と`medu`でVIFが高くなっています。一般的にVIF>10で多重共線性の問題があると言われていますので、人工的に作った`tmp`はかなり大きな多重共線性を発生させています。

一方で、関係ない変数`mbsmoke`は、VIF=1.04で蚊帳の外です。

最後の`predict`コマンドで、この回帰モデルでの予測値を算出し、`xb1`として新しい変数に保存しました。

## 多重共線性がない線形回帰モデル
では、人工的につくった`tmp`を除いて同じことをやってみます。

```
regress bweight mbsmoke mage medu
estat vif
predict xb2
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/448182d8-dc9d-4ecf-89e9-5b205ab64f4c)

当たり前ですが、VIFは最大でも1.24です。多重共線性はないと考えて良いでしょう。

ここで、さっきから蚊帳の外だった`mbsmoke`の回帰係数を見てみましょう。多重共線性がかなりかかっていたさっきの値は`-249.77`であるのに対し、今回は`-249.51`でした。多少の違いはあるものの、ほとんど変わりません。そのほかの多重共線性の影響があった変数（`mage`と`medu`）では回帰係数が大きく変化しているのと対照的です。

つまり、**多重共線性と関係ない変数については、他変数間で多重共線性があっても影響をうけない**ということです。因果推論の文脈でも、交絡変数間で多重共線性があったとしても、曝露変数には多重共線性がなければ、気にしなくてもよいということです。

## 2つのモデルで予測値を比較する
今回は、予測ですので、予測値についても確認します。予測値（`xb1'と`xb2`）についてサマライズします。

```
su xb*
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/a9fbcf31-91e2-4482-afde-1822da3a679c)

平均値は同一で、その他の統計量も近い値になっています。

キャリブレーションプロットで状況をより詳細に確認しましょう。

```
twoway ///
  (scatter xb1 xb2 , mcolor(blue%15)) ///
  (function y=x, range(2800 3800) lcolor(navy)), ///
  legend(label(1 "xb1-xb2") label(2 "y=x"))
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/4d527cb1-9d23-43ef-b98d-e39de304af7f)

ほぼすべての点が、直線上に乗っていて、2つの方法がほぼ同じ値をとっていることがわかります。

つまり、**多重共線性を生じるような変数（今回は`tmp`）を回帰式に加えても、悪影響を及ぼしていないことがわかります**。ただし、良い影響もありません。

このようなことから、予測値を求めるときには多重共線性を気にしなくても特に問題ないということです。

# ここまでやった方法がよろしくない理由
ここまで2つのモデル（変数3個モデルと変数273個モデル）で予測を行い、その予測能力の検証を行いました。

しかし、ここまでやった方法は脱法予測です。論文化においてこのような方法で予測モデルを作ったとしたら、考察で限界点を記述する必要がありますし、査読者の強い攻めに耐える必要があります。

何がいけなかったのでしょうか？

## 学習データと検証データが一致している。
学習データと検証データが一致していることが、最大の問題点です。

今回は4,642人のデータを用いて、線形回帰分析を行い予測値を算出しました（学習）。そして、予測能力を同じ4,642人のデータを用いて計算しました（検証）。

学習データと検証データが一致していると、当たり前ですが、予測能力が高く評価されます。本来、予測は未知のデータに対して行いたいはずです。今回のように出生時体重であれば、これから生まれてくる新生児体重を予測しなければなりません。これから生まれてくる新生児体重は、当然ながらデータはありません。あるのは予測変数（両親のデータ）のみです。

そのため、学習データと検証データを分けて考えていく必要があります。

早速やってみましょう。

## データセットを分割する。
データセットを学習データと検証データに分割します。

このようにランダムにデータを分割するためには`splitsample`コマンドが利用できます。このコマンドの詳細については`help splitsample`で調べてください。

```
splitsample, generate(svar, replace) split(0.2 0.8) show rseed(12345)
```

今回はこの設定で実行します。
* `gen`オプションは分割したデータには印をつけますが、その印を`svar`にしているという意味です。
* `split`オプションは、どのような分割にするかをしていします。今回は20％と80％に分割しています。
* `show`オプションは、`gen'オプションで作った変数（今回は`svar`）の表を作ります。
* `rseed`オプションは、乱数シードを固定します。

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/69ea9535-e777-43cb-9ccb-32e467e7bd3a)

端数の関係でぴったり20%にはなっていませんが、20:80に分割されていることがわかります。

今回は、80%の方（`svar==2`）で学習し、20％の方（`svar==1`）で検証します。

## 学習データで線形回帰分析を実行する。
ここでやることは、前回と同じです。一気にやってしまいましょう。

まずは、3変数モデルです。母親の年齢`mage`、学歴`medu`、飲酒`alcohol`の3変数で、出生児体重`bweight`を予測します。

学習データのみを利用した数式で予測するので、`regress`コマンドには`if svar==2`が付いていることに注意してください。

また、その数式を用いて、検証データ側も予測値を算出するので、`predict`には`if svar==2`がついていません。
```
* 3変数モデルの予測
regress bweight mage medu alcohol if svar==2
predict bw_pred_reg1, xb
predict resi_pred_reg1, residual
```

つぎに、273変数モデルです。こちらも学習データのみを利用するので、`regress`コマンドには`if svar==2`が付いていることに注意してください。
```
* 273変数モデルの予測
vl set
vl create xcate = (mmarried mhisp fhisp foreign alcohol deadkids msmoke mbsmoke mrace frace prenatal fbaby prenatal1 order birthmonth)
vl create xcont = (monthslb mage medu fage fedu nprenatal)
vl substitute predvars1 = c.xcont##c.xcont
vl substitute predvars2 = i.xcate##i.xcate
vl substitute predvars3 = i.xcate#c.xcont
regress bweight $predvars1 $predvars2 $predvars3 if svar==2
predict bw_pred_reg2, xb
predict resi_pred_reg2, residual
```

## 検証データで予測値を評価する。
次に、検証データを用いて予測能力を評価します。評価指標は前回と同じく、RMSEとRMSPEです。
* RMSE = Root Mean Squared Error
* RMSPE = Root Mean Squared Percentage Error

$$RMSE = \sqrt{\frac{1}{n}\sum_{i=1}^{n}(y_i - \hat{y_i})^2}$$

$$RMSPE = \sqrt{\frac{1}{n}\sum_{i=1}^{n}(\frac{y_i - \hat{y_i}}{y_i})^2}$$

まず、3変数モデルから検証します。検証データのみを使うので`if svar==1`が付いていることに注意してください。
```
gen resisq_pred_reg1  = resi_pred_reg1 * resi_pred_reg1 if svar==1
gen resisq_pred_reg1p =  (resi_pred_reg1 / bweight)^2   if svar==1

su resisq_pred_reg1 if svar==1
local rmse = sqrt(`r(mean)')

su resisq_pred_reg1p if svar==1
local rmspe = sqrt(`r(mean)')

di `rmse'
di `rmspe'
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/15d87151-603c-46a5-ae25-609f3b1e3fd9)

RMSE=591.8、RMSPE=0.462でした。これは前回の数値（RMSE=573.2、RMSPE=0.418）よりも悪くなっています。むしろ、前回が不当に良かっただけですが。

次に、273変数モデルも検証します。やはり、検証データのみを使うので`if svar==1`が付いていることに注意してください。
```
gen resisq_pred_reg2  = resi_pred_reg2 * resi_pred_reg2  if svar==1
gen resisq_pred_reg2p =  (resi_pred_reg2 / bweight)^2     if svar==1

su resisq_pred_reg2  if svar==1
local rmse = sqrt(`r(mean)')

su resisq_pred_reg2p  if svar==1
local rmspe = sqrt(`r(mean)')

di `rmse'
di `rmspe'
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/5a845f53-e398-4d94-ad06-85171daebd33)

RMSE=970.9、RMSPE=0.434でした。これは前回の数値（RMSE=498.2、RMSPE=0.300）よりも悪くなっています。RMSEにいたっては3変数モデルに完敗しています。苦労した割にあまり良くないモデルであるということになります。

## キャリブレーションプロット
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

# 次回
3変数モデルと273変数モデルの勝負は、学習データと検証データを分割して評価すると、前回とは異なった結果になりました。

273変数モデルは変数が多すぎて過学習を起こしている状況です。変数がかなり多く、わずかなノイズにもフィットするモデルなので、学習データに過剰にフィットしたものの、それ以外のデータ（検証データ）では良くない結果になりました。

では、変数が少ない方が予測能力が高いのでしょうか。次回は予測のために効率的な予測のための方法を紹介します。

# 時間が余ったとき…
[なぜプログラミングが必要なのか？](https://github.com/sankyoh/Stata_Lecture2022/blob/main/Lecture_01_introduction.md#%E3%81%AA%E3%81%9C%E3%83%97%E3%83%AD%E3%82%B0%E3%83%A9%E3%83%9F%E3%83%B3%E3%82%B0%E3%81%8C%E5%BF%85%E8%A6%81%E3%81%AA%E3%81%AE%E3%81%8B)


[^1]:[Efficient semiparametric estimation of multi-valued treatment effects under ignorability](https://www.sciencedirect.com/science/article/pii/S030440760900236X)
[^2]:多重共線性？　何それ、食べれるの？
