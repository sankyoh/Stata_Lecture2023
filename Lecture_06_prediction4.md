# 前回までの復習

妊娠時の変数を用いて、出生児体重を予測するためのモデルを色々な方法で作成しました。

今回は、線形回帰分析（3変数・273変数）、ステップワイズによる変数選択、LASSOによる変数選択、ランダムフォレストを採用しました。

その結果、このデータでは、ランダムフォレストによる予測が最も制度が良さそうです。

なお、ランダムフォレストのハイパーパラメータは`rforest`の初期設定のままです。

|モデル|RMSE|RMSPE|
|----|----|----|
|3変数モデル|591.8|0.462|
|273変数モデル|970.9|0.435|
|Backwardステップワイズ|658.8|0.383|
|Forwardステップワイズ|579.7|0.383|
|LASSO回帰|566.6|0.419|
|ランダムフォレスト|473.9|0.267|


今回は、この予測を用いた因果推論について説明します。

なお、予測を上手く使う事で因果を推定することも可能です。最終的にはこれを目指します。この「予測を用いて、因果関係を推定する」というコンセプトは、[Causal Inference for The Brave and True](https://matheusfacure.github.io/python-causality-handbook/landing-page.html)に影響を受けています。

# 求めたい効果：CATEについて

今シリーズで因果効果の指標として推定対象（Estimand）としているのは、「条件づき平均処置効果（CATE:Conditional Average Treatment Effect）」です。

平均処置効果（ATE:Average Treatment Effect）は、知りたい対象者達の集団全体における因果効果ですが、CATEは変数が一定の値をもっている者の因果効果です。

例えば、集団の男女全体の因果効果はATEになりますが、男性のみの因果効果をみる場合は男性のCATEになります。

式であらわすと下記の様な違いがあります。

$$ATE = E[Y_i^1-Y_i^0]$$

$$CATE = E[Y_i^1-Y_i^0|X] = E[\tau_i|X]$$

なお、CATEのことを記号では**τ**で表します。

## CATEを求めたいモチベーション

* 予防/治療するのにコストがかかるときには、「どのような集団に介入すると効率的か？」がわかる。
* 曝露によって大きくマイナス方向の影響を受ける集団を特定することで、「誰が特に注意するべきか？」わかる。
* 集団内で効果が異なるサブ集団があるときには、ATEでは意味をなさない（男性はマイナス10、女性はプラス10の効果があり、男女比＝1：1だと、ATE=0になる）。

# 今回からの課題
曝露の有無を「妊婦の喫煙の有無」として、妊婦の喫煙が出生児体重に与える効果をCATEとして算出したいと思います。

今回は、妊婦年齢による効果の異質性に着目し、下記の様なτ(x)を求めようと思います。

つまり、喫煙が出生児体重に与える影響は、妊婦年齢によってどのように異なっているのかを調べたいと思います。

$$ \tau(x) = E[Y_i^{smoking=1} - Y_i^{smoking=0}|age=x]$$

# Meta-learners
Meta-learnersは、機械学習モデル（予測モデル）を用いて、CATEを計算するための方法です。「Learner**s**」複数形になっているように、いくつかの方法が含まれています。

Meta-learnersのうち、どれもそれぞれ利点と欠点があり、どれが役に立つのかはその状況によりますが、Pubmedで見るとX-learnerしか見つかりませんでした。

次から紹介するように、Meta-learnersでは、1個以上のBase learnerを用います。そのBase learnerに線形回帰、決定木（ランダムフォレスト）、ニューラルネットワーク、ガウス過程まで様々な予測モデルを用いることができます。

Meta-learnersによる因果推論が適切に行えるかどうかは、Base learnerとしてどの予測モデルを使うかにも大きく依存します。

Pythonでは、Meta-learnerのためのライブラリが用意されていて、簡単に実装することができます。

Stataでは、そのようなライブラリが（今のところ）無い様なので、スクラッチにコードを書いていく必要があります。

## データの準備
データの読込みを行います。さらに、`vl set`で変数の定義だけ行っておきます。予測変数から`msmoke`と`mbsmoke`が抜けていることに注意して下さい。

```
* データ読み込み
use https://www.stata-press.com/data/r18/cattaneo2, clear

* IDを作っておく
gen id = _n

* 変数リストの定義
vl set
vl create xcate = (mmarried mhisp fhisp foreign alcohol deadkids mrace frace prenatal fbaby prenatal1 order birthmonth)
vl create xcont = (monthslb mage medu fage fedu nprenatal)
```

## S-learner
最もシンプルな**S-learner**から紹介します。Sは**Single**を表しています。

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/15d48c63-f7cd-421e-901a-7816ebb46bb1)

図表：https://matheusfacure.github.io/python-causality-handbook/21-Meta-Learners.html からの引用

### 文字の定義

* X:共変量
* T:処置の有無
* Y:アウトカム
* y*:モデルを用いたアウトカムの予測値

### 学習

$$\mu(t,x)=E[Y|T,X]$$

図の左側に相当します。処置の有無（T）と共変量（X）を用いて、アウトカムを予測する予測モデルを構築します。

ここでは、ランダムフォレストを採用します。また、後々のために`expand`でデータセットを3倍に拡張し、ブロック1～3を作ります。1つ目がオリジナルデータ、2つ目が全員曝露データ、3つめが全員非曝露データとなるように作っています。

```
* データセットの拡張
expand 2, gen(expand1)
expand 2 if expand1==0, gen(expand2)
tab expand*

gen     block=1 if expand1==0 & expand2==0
replace block=2 if expand1==1 & expand2==0
replace block=3 if expand1==0 & expand2==1
label define block 1 "original" 2 "all exposed" 3 "all unexposed"
label values block block

* ブロックごとに曝露変数の改変
replace mbsmoke = 1 if block==2
replace mbsmoke = 0 if block==3

* リストで見る
list block mbsmoke in 4640/4650, sepby(block)
list block mbsmoke in 9280/9290, sepby(block)
```

学習は、オリジナルデータ（`block==1`）のみで行います。人工的に作った全員曝露データや全員非曝露データは学習では使いません。

```
rforest bweight mbsmoke $xcate $xcont if block==1, type(reg) seed(12345)
```

#### ランダムフォレストの学習評価
前回までのようにRMSEやRMSPEを算出してもいいのですが、ランダムフォレストには**OOBエラー**（Out-of-bag Error）を計算することができます。

ランダムフォレストでは、ブートストラップでリサンプリング（ランダムの復元抽出）して、何度も計算しています（`rforest`の標準では100回）。

ランダム復元抽出を行うので、元データの中には一回も選ばれないデータ行が存在します。そのようなデータ行のことを**Out-of-bag**と言います。このOut-of-bagは十分にサンプルサイズが大きければ36%程度に収束することが分かっています。

このOut-of-bagに対して、予測値と実測値の誤差を評価することで、ランダムフォレストの学習評価を行なうことができます。

幸い、Stataの`rforest`コマンドでは、標準で計算されています。

```
ereturn list
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/1bcf00f0-3a3a-48ed-920c-98328f2f38a0)

この結果からOOBエラー=424と分かります。今回の乱数の出目は良かったのか、それなりに小さい数値になりました。

### 学習結果を用いた予測

今度は図の右側です。

3つのブロック全てで予測を行いました。
ブロック2とブロック3は、反事実モデル（全員曝露、全員非曝露）での予測になっています。

```
predict pred_s
```

このうち全員曝露（ブロック2）の予測値と全員非曝露（ブロック3）の予測値の差が仮想的な個人の曝露効果（ITE:Individual Treatment Effect / Imputed Treatment Effect）になっています。

この差を求めるための操作を行います。

```
sort id block
list id block pred_s in 1/12, sepby(id)
```
![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/ef9e490b-6f05-4b23-8ac0-26179737cb4b)

```
bys id:gen y1hat = pred_s[2]
bys id:gen y0hat = pred_s[3]
gen ite = y1hat - y0hat
label variable ite "Imputed Treatment Effect"

list id block pred_s y1hat y0hat ite in 1/12, sepby(id)
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/84d21026-a59c-4237-9c1f-b0843ea36322)

ITEが算出されていますが、id=1の方は喫煙すると出生児体重が-236gになり、id=2の方は喫煙により-111gになると予測されています。

こうなると、ブロック2とブロック3はもう要らないので、消してしまします。

```
drop if block!=1
```

### 結果の評価
最終的な目的だった妊婦年齢と因果効果の関係を確認します。

```
twoway scatter ite mage, jitter(5) jitterseed(12345) mcolor(stblue%20) || fpfit ite mage, legend(label(1 "Scatter") label(2 "FP fit"))
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/f1e22edd-bc18-4ca7-b40b-832fbd076510)


うっすらと、右肩下がりのように見えますが、多分気のせいです。


## T-learner
次は、S-learnerを発展させた**T-learner**についてです。Tは**Two**とか**Twin**を表しています。

実装はこちらの方がシンプルです。

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/a984a497-79c0-44dc-b75b-c9535e382284)

図表：https://matheusfacure.github.io/python-causality-handbook/21-Meta-Learners.html からの引用

### 文字の定義

* X:共変量
* T:処置の有無
* Y:アウトカム
* y*:モデルを用いたアウトカムの予測値

### 学習と予測

まず、学習から行います。
$$\mu_0(x)=E[Y|T=0,X]$$
$$\mu_1(x)=E[Y|T=1,X]$$

図の左側に相当します。処置の有無（T）と共変量（X）を用いて、アウトカムを予測する予測モデルを構築します。S-learnerとの違いは、曝露群・非曝露群に分けて学習モデルを構築することです。

データ読み込み後のコードです。

```
* 非曝露の学習・予測：非曝露群における予測モデルの構築とそれを用いた予測
rforest bweight $xcate $xcont if mbsmoke==0, type(reg) seed(12345)
ereturn list
predict pred_t0

* 曝露群の学習・予測：曝露群における予測モデルの構築とそれを用いた予測
rforest bweight $xcate $xcont if mbsmoke==1, type(reg) seed(12345)
ereturn list
predict pred_t1
```
OOBエラーは、非曝露群で424g、曝露群で420gであり、許容できる程度には小さいようです。

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/d471b41c-425e-41cb-afc6-8f13aadde5c9)

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/9bd1539f-585d-42e6-85ed-b63fabfef5ad)


S-learnerと同様にITEを計算します。

```
gen ite = pred_t1 - pred_t0
label variable ite "Imputed Treatment Effect"

list id mbsmoke bweight pred_t1 pred_t0 ite in 1/20, sep(0)
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/45139262-da57-4dd6-aa43-726534a9cb78)


### 結果の評価
最終的な目的だった妊婦年齢と因果効果の関係を確認します。

```
twoway scatter ite mage, jitter(5) jitterseed(12345) mcolor(stblue%20) || fpfit ite mage, legend(label(1 "Scatter") label(2 "FP fit"))
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/97f13410-c802-404d-8392-1af27d5282a3)

こころなしか、S-learnerよりも右肩下がりが強くなった感じがしませんか？

# 次回
次回はさらに複雑なMeta-learnerである**X-learner**を紹介します。

