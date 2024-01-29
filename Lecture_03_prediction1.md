# 予測
疫学分野では、どちらかというと因果推論に重きを置いた講義・話題が多いかと思います。ここでは、珍しく予測を行う方法について、いくつか説明を行います。

なお、予測を上手く使う事で因果を推定することも可能です。最終的にはこれを目指します。この「予測を用いて、因果関係を推定する」というコンセプトは、[Causal Inference for The Brave and True](https://matheusfacure.github.io/python-causality-handbook/landing-page.html)に影響を受けています。

## 因果と予測の違い
因果と予測は異なります。

例えば、タバコは肺癌のリスクを高めます（因果関係）が、ライター所持は肺癌リスクを高めません。

しかし、ライター所持している人は将来に肺癌になる可能性が高いと予想できます（予測）。これは、ライター所持に因果関係がなかったとしても、ライター所持はタバコを介して肺癌と関連があるためです。このように、予測可能な変数は、因果関係がある変数よりも広い範囲になります。

DAGとして考えると、次の2つの条件があればアウトカムを予測する変数であると考える事ができます。
* 何らかのパスでアウトカムと繋がっていること
* 時間的にアウトカムよりも先であること

# 予測を行う
## サンプルデータ
サンプルデータを用いて、アウトカムの予測を行います（正確には、予測可能な統計モデルを作成します）。

利用するサンプルデータは、「cattaneo2」です。これは、妊婦の状況を示す変数と出生児体重が記録されています。このデータを用いた論文[^1]は、2010年に発表されています。下記のコマンドで利用可能です。

```
use https://www.stata-press.com/data/r18/cattaneo2, clear
```

ここでは（元のCattaneoの論文とは異なり）出生前の変数を用いて、出生児の体重の予測を行います。

特別な理由が無い限り、ここでは用語を次の様に定義します。
* アウトカム変数・応答変数 = 予測される変数（ここでは、出生児体重）
* 説明変数・予測変数 = 予測をするために用いる変数（ここでは、母親の年齢など）

今回の応答変数は、連続量なので一般的な線形回帰分析を用いて予測を始めます。

## 線形回帰分析による予測
最初はシンプルに予測します。例として、母親の年齢`mage`、学歴`medu`、飲酒`alcohol`の3変数で、出生児体重`bweight`を予測します。

```
regress bweight mage medu alcohol
predict bw_pred_reg1, xb
predict resi_pred_reg1, residual
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/9e1c43b2-52fe-4fc7-89b0-35f64979ae41)

回帰分析は上記の様な結果になりました。そして、回帰分析をした後に、そのモデルによる予測値と残差を算出しています。

研究者が、回帰分析を行い、予測したとすると、次のような式で予測ができると仮定・主張しています。

$$bweight = 2937 + 7.75×mage + 17.7×medu -171.8×alchohol$$

なお、残差がありますので、この式で計算された`bweight`は観察値と一致はしません。次に、予測結果をみてみましょう。

```
su bw* resi*
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/2c8056f0-6698-4a60-af82-45e9e9dcd408)


観察値と予測値ではほぼ一致した平均値になっています（これは、線形回帰分析がそうなるように計算しているので自明ですが）。

しかし、個々の値は大きくはずしているところも有る点に注意が必要です。予測値が観察値とどのくらい近いかを評価する必要があります。残差をみると、その平均値はほぼゼロです。これは予測値と実測値の平均が一致していることを反映しています。プラス方向のズレとマイナス方向のズレが相殺してしまい、ほぼゼロになります。

これでは、予測精度を見るために残差は不適切です。

そこで、RMSEやRMSPEという指標を用います。これは次の様に定義されます。
* RMSE = Root Mean Squared Error
* RMSPE = Root Mean Squared Percentage Error

$$RMSE = \sqrt{\frac{1}{n}\sum_{i=1}^{n}(y_i - \hat{y_i})^2}$$

$$RMPSE = \sqrt{\frac{1}{n}\sum_{i=1}^{n}\frac{(y_i - \hat{y_i})^2}{y_i}}$$

これらの値を計算して、予測モデルの性能が良いのかどうか検証します。

```
gen resisq_pred_reg1  = resi_pred_reg1 * resi_pred_reg1
gen resisq_pred_reg1p =  (resi_pred_reg1 / bweight)^2

su resisq_pred_reg1
local rmse = sqrt(`r(mean)')

su resisq_pred_reg1p
local rmspe = sqrt(`r(mean)')

di `rmse'
di `rmspe'
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/1ad1b3f8-70e6-4747-990b-2a1d101ac2ec)


この結果は、「ろくに予測出来ていない」といってもいいくらいです。

RMSEは「平均的に570gくらい予測値はズレている」という意味です。新生児の体重予測を570gも外していては、予測の意味がなさそうです。

RMSPEは「平均的に41.8%ズレている」という意味になります。これについては、壊滅的です。500g以下の出生体重児であっても2800gなどの予測値になっているため、RMSPEでは特にズレが大きく評価されます。

## 予測精度を高める
それでは、予測精度を高めるために**予測変数を増やしてみます**。増やすからには、考えられるだけ増やします。
* 予測変数として、可能性のある変数全ての1次項（21）
* 連続変数の2乗項（6）
* 交互作用項（210）

括弧内は個数ですので、合計237個になります。これらを全てを予測変数として回帰分析に突っ込んでみます[^2]。

今回の「予測変数として、可能性のある変数」は、下記とします。
mmarried mhisp fhisp foreign alcohol deadkids mage medu fage fedu nprenatal monthslb order msmoke mbsmoke mrace frace prenatal birthmonth

### 予測変数候補（大量）の準備の準備をする。
大量の予測変数候補を手打ちでコマンド入力することはあまり現実的ではありません。`vl`コマンドを上手く使って楽にやっていこうと思います。

`vl`コマンドは、変数リスト（Variable List）を操作するためのコマンド群です。サブコマンドをいろいろ活用する事で、変数のグループ化が可能です。

グループは、`$vlcategorical`等のグローバルマクロの形でまとめられています。

```
vl set
```
![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/6306b439-20ed-41cb-b307-dfb5f03376ab)

このコマンドによって、全部で27個ある変数のうち、カテゴリー変数`$vlcategorical'、連続変数`$vlcontinuous`、判断保留`$vluncertain`、その他`$vlother`の4つに振り分けられます。

今回は、カテゴリー変数14個、連続変数6個、判断保留7個、その他なし、という分類になりました。

具体的にどの変数がどこに割り振られているか確認します。

```
vl list
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/c0c161f7-74f8-4ea9-91d7-6b8dd92311e9)

カテゴリー変数と連続変数に割り当てられた変数は、それで正しそうです。また、先ほどの過程で作った変数（bw_pred_reg1 resi_pred_reg1 resisq_pred_reg1 resisq_pred_reg1p）は、連続変数になっています。

`$vluncertain`の7個を確認します。`mage`、`medu`、`fage`、`fedu`、`nprenatal`は、連続変数とし、`order`、`birthmonth`はカテゴリ変数とします。

```
vl move (mage medu fage fedu nprenatal) vlcontinuous
vl move (order birthmonth) vlcategorical
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/29ce2c82-eba2-4157-9afc-765058607bf7)

変数の割振り状況が更新されたことがわかります。

もう一回、割振り状況を確認します。

```
vl list
```

グローバルマクロでまとめられていますので、次の様なコマンドも利用できます。

```
di "The categorical variables are: $vlcategorical"
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/86414a2e-4a22-4b38-a680-f7340aa378ea)

### 予測変数候補（大量）の準備をする。
ここまでは、単に変数リストの特性（カテゴリ変数か連続変数か）の整理を行ったに過ぎません。

次の変数の役割を元に仕分けします。そのために、次の2つの新しい変数区分を作成します。
* $xcate: 予測変数（カテゴリ変数）
* $xcont: 予測変数（連続変数）

`vl`で使う変数区分を新たにつくるには、vl createで可能です。

```
vl create xcate = (mmarried mhisp fhisp foreign alcohol deadkids msmoke mbsmoke mrace frace prenatal fbaby prenatal1 order birthmonth)
vl create xcont = (monthslb mage medu fage fedu nprenatal)
vl list
```

アウトプットは省略しますが、新たに`$xcate`グループと`$xcont`グループが作成されています。

```
di "$xcate $xcont"
```

### 予測変数候補（大量）を作成する。
さて、ここまでで作成した`$xcate`と`$xcont`を活用して、一気に大量の予測変数を作りたいと思います。

`vl substitute`は、接頭辞や「#」記号を使った加工を行い、それを新たな変数グループにまとめることができます。

```
vl substitute predvars1 = c.xcont##c.xcont
vl substitute predvars2 = i.xcate##i.xcate
vl substitute predvars3 = i.xcate#c.xcont
```

一行目では連続変数同士の交互作用項・一次項・二乗項）、二行目ではカテゴリー変数同士の交互作用項・一次項・二乗項、三行目では連続変数とカテゴリー変数の交互作用項を作っています。

内容を見てみます。

```
di "predvar1 are: $predvars1"
di "predvar2 are: $predvars2"
di "predvar3 are: $predvars3"
```

大量に表示されますが、これで全組み合わせがあります。つまり、`$predvars1 $predvars2 $predvars3`という記載で、大量の予測変数を表現しています。

これを人間の手で考えながら、打ち込むことは不可能です。下記にて、計算上の237個すべてが作成されていることが確認できます。

```
di "$predvars1 $predvars2 $predvars3"
local tmp $predvars1 $predvars2 $predvars3
local i = 1
foreach x of local tmp {
  di "`i++': `x'"
}
```

### 回帰分析を行う。
上の過程で237個の説明変数が作成できたので、線形回帰分析を行います。

```
regress bweight $predvars1 $predvars2 $predvars3
predict bw_pred_reg2, xb
predict resi_pred_reg2, residual

gen resisq_pred_reg2  = resi_pred_reg2 * resi_pred_reg2
gen resisq_pred_reg2p =  (resi_pred_reg2 / bweight)^2

su resisq_pred_reg2
local rmse = sqrt(`r(mean)')

su resisq_pred_reg2p
local rmspe = sqrt(`r(mean)')

di `rmse'
di `rmspe'
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/cffb1dcc-e4a6-4360-843a-f57a81606a19)

RMSEは573.2gから498.2gに改善し、RMSPEは0.418から0.300に改善しました。つまり、予測変数を3個から273個に増やす事によって予測能力は改善しました。

しかし、これで良いでしょうか…？

# 次回
このようなやり方が良く無い理由と多重共線性を気にしていない理由などを含めて、改善していきます。
（なお、予測モデルを作りながら講義資料をつくっているので、上手くいくかどうか保証がありません）

# 時間が余ったとき…
[なぜプログラミングが必要なのか？](https://github.com/sankyoh/Stata_Lecture2022/blob/main/Lecture_01_introduction.md#%E3%81%AA%E3%81%9C%E3%83%97%E3%83%AD%E3%82%B0%E3%83%A9%E3%83%9F%E3%83%B3%E3%82%B0%E3%81%8C%E5%BF%85%E8%A6%81%E3%81%AA%E3%81%AE%E3%81%8B)


[^1]:[Efficient semiparametric estimation of multi-valued treatment effects under ignorability](https://www.sciencedirect.com/science/article/pii/S030440760900236X)
[^2]:多重共線性？　何それ、食べれるの？
