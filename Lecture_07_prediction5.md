# 前回までの復習

予測モデルを用いて、因果推論を行う方法として、**S-Learner**と**T-Learner**について紹介しました。これらを使ってCATE(age)を描画していました。

S-Learnerの場合（右肩下がりのように見えるが、下に凸なグラフなので最後にちょっと上がっている）

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/f1e22edd-bc18-4ca7-b40b-832fbd076510)

T-Learnerの場合（もうちょっとはっきりと右肩下がりに見える）

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/97f13410-c802-404d-8392-1af27d5282a3)

今回は更に発展的な**X-Learner**について紹介します。

この「予測を用いて、因果関係を推定する」というコンセプトは、[Causal Inference for The Brave and True](https://matheusfacure.github.io/python-causality-handbook/landing-page.html)に影響を受けています。

# 求めたい効果：CATEについて（復習）

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

# 前回からの課題
曝露の有無を「妊婦の喫煙の有無」として、妊婦の喫煙が出生児体重に与える効果をCATEとして算出したいと思います。

今回は、妊婦年齢による効果の異質性に着目し、下記の様なτ(x)を求めようと思います。

つまり、喫煙が出生児体重に与える影響は、妊婦年齢によってどのように異なっているのかを調べたいと思います。

$$ \tau(x) = E[Y_i^{smoking=1} - Y_i^{smoking=0}|age=x]$$

# X-learner
今回は**X-learner**から紹介します。Xは**図中にある矢印のクロス**を表しています。

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/101e606b-3de0-43f0-98a3-52f668144288)

図表：https://matheusfacure.github.io/python-causality-handbook/21-Meta-Learners.html からの引用

## 文字の定義

* X:共変量
* T:処置の有無
* Y0:アウトカム（処置無し）
* Y1:アウトカム（処置あり）


## 学習の手順

X-Learnerでは、4つのBase-Learnerを用います。Fisrt Stageで2つ、Second Stageで2つです。

### First Stage

図の左側部分に相当します。処置の有無に分けて予測モデルを作成します。

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/0449236c-fcc5-45d6-a8d4-795b45bf891b)

まず、処置なし（T=0）の集団において、共変量Xを用いてアウトカムY0を予測するモデルを作成します。この予測モデルをM0(X）とします。M0(X)は共変量Xを投入すると、処置がない場合におけるアウトカムの予測値を返す関数です。

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/64988a08-f813-4fb4-893a-91e32514def7)


次に、処置あり（T=1）の集団において、共変量Xを用いてアウトカムY1を予測するモデルを作成します。この予測モデルをM1(X）とします。M1(X)は共変量Xを投入すると、処置がある場合におけるアウトカムの予測値を返す関数です。

式で表すと、次の様になります。

$$M_0(X)=E[Y|T=0,X]$$

$$M_1(X)=E[Y|T=1,X]$$

### Second Stage（ア）

図の右側部分に相当します。

最初にさっき使った予測モデルを用います。上側（処置なし群）から見ていきます。

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/ec2a7c18-5729-4f27-bcb5-6ca86950648c)


処置なし群についてM1(X)を計算します。M1(X)にXを代入すると出てくるのは、「処置があったときのアウトカムの予測値」です。**処置なし群におけるM1(X)は、反事実アウトカム（処置あり時アウトカム）の予測値**になっています（現実には処置なしだが、もし仮に処置があったとしたら、どのようなアウトカムになっていたのかを予測している）。


このM1(X)から観測値Y0を引くと、処置なし群のITE(Inputed Treatment Effect)となります。図中では**CATE0**となっています。

$$ITE(X, T=0) = M_1(X,T=0) - Y_{T=0}$$

次に下側（処置あり群）を見ていきます。行っていることは上側と同様です。

処置あり群についてM0(X)を計算します。M0(X)にXを代入すると出てくるのは、「処置がなかったときのアウトカムの予測値」です。**処置あり群におけるM0(X)は、反事実アウトカム（処置なし時アウトカム）の予測値**になっています（現実には処置ありだが、もし仮に処置がなかったとしたら、どのようなアウトカムになっていたのかを予測している）。

観測値Y1からこのM0(X)を引くと、処置あり群のITEとなります。図中では**CATE1**となっています。

$$ITE(X, T=1) = Y_{T=1} - M_0(X,T=1)$$

### Second Stage（イ）

Second Stage（ア）で、処置なし群と処置あり群の両方でITEを計算できました。図中では、CATE0とCATE1となっています。

これを使って次の作業を行います。

上側（処置なし群）から見ていきます。ここでは、処置なし群において、共変量Xを用いてITEを予測するモデルを作っています。この予測モデルをM_ITE0(X）とします。M_ITE0(X)は共変量Xを投入すると、処置がない場合におけるITEの予測値を返す関数です。

次に、下側（処置あり群）を見ていきます。処置あり群において、共変量Xを用いてITEを予測するモデルを作っています。この予測モデルをM_ITE1(X）とします。M_ITE1(X)は共変量Xを投入すると、処置がある場合におけるITEの予測値を返す関数です。

式で表すと、次の様になります。図中ではMTAU0(X)とMTAU1(X)となっています。

$$M_{ITE0}(X)=E[ITE|T=0,X]$$

$$M_{ITE1}(X)=E[ITE|T=1,X]$$

### Second Stage（ウ）

最後にM_ITE0(X）とM_ITE1(X）を合成して完成です。合成の方法は**重み付き平均**です。

重みとして利用するのが、図中の下に現れたPS(X)です。これは傾向スコアのことを指しています。ロジスティック回帰モデルであれば、下記の式で傾向スコアが計算可能です。

もちろん、ロジスティック回帰モデル以外で計算しても構いませんが、X-learnerですでにお腹いっぱいなので、ロジスティック回帰モデルにしておきましょう。

$$ logit(PS) = β_0 + \sum_{n=1}^k(β_k X_k)$$

最終的には、傾向スコアで重み付けた平均値を最終的なCATEとします（図中ではCATE Final）。

式で表すと次の様になります。

$$CATE = M_{ITE0}(X)PS(X) + M_{ITE1}(X)(1-PS(X))$$

# X-learner:Stataでの実装

さて、手順がわかった（？）として、具体的にStataで実装していきたいと思います。

## データの準備
データの読込みを行います。さらに、`vl set`で変数の定義だけ行っておきます。

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

## First StageとSecond Stage（ア）

次に **First StageとSecond Stage（ア）** の手順を一気に進めます。

まず、非曝露群から行います。

```
* ***** ***** ***** ***** ***** ***** ***** ***** ***** ***** 
*
* 非曝露の学習：非曝露群における予測モデルの構築とそれを用いた予測
*
* ***** ***** ***** ***** ***** ***** ***** ***** ***** *****
* ----- ----- M0(X,T=0)の作成 ----- -----
rforest bweight $xcate $xcont if mbsmoke==0, type(reg) seed(12345)
ereturn list

* ----- ----- ITE1 = Y1 - M0(X,T=1)の算出 ----- -----
predict pred_m0 if mbsmoke==1
gen ite1 = bweight - pred_m0 if mbsmoke==1
```

ランダムフォレストの予測能をOOBエラーで見ておきます。OOBエラーについては、前回講義で紹介したとおりです。小さい方が嬉しいのですが、どうか…

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/38b84f63-a344-41ec-87e2-acdc737b2fa1)

OOBエラー = 424.1でした。許容範囲内としましょう。

つぎに、曝露群について同様の手順を行います。

```
* ***** ***** ***** ***** ***** ***** ***** ***** ***** ***** 
*
* 曝露群の学習・予測：曝露群における予測モデルの構築とそれを用いた予測
*
* ***** ***** ***** ***** ***** ***** ***** ***** ***** *****
* ----- ----- M1(X,T=1)の作成 ----- -----
rforest bweight $xcate $xcont if mbsmoke==1, type(reg) seed(12345)
ereturn list

* ----- ----- ITE1 = Y1 - M0(X,T=1)の算出 ----- -----
predict pred_m1 if mbsmoke==0
gen ite0 = pred_m1 - bweight if mbsmoke==0
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/a200a63b-8e12-44a1-8e34-78ae50f5e74f)

OOBエラー = 420gであり、許容できる程度には小さいようです。

ITE0とITE1が計算できたので、ちょっと確認しておきましょう。確認ですが次ような意味です。

ITE0: 非曝露群における個人の因果効果の予測値
ITE1: 曝露群における個人の因果効果の予測値

```
su ite*
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/9b5ffaa0-fa45-4056-b2df-b9973265acf2)

ITE0の平均値は約-240.7gで、ITE1の平均値は約-229.3gです。妊婦喫煙による出生児体重減少の効果（計算値）は、曝露群で少し大きいようです。

## Second Stage（イ）

次に、**Second Stage（イ）** に進みます。

まずは、非曝露群データを用いて、予測変数Xを用いてITE0を予測するモデルを作ります。

ここで突然の`replace ite0=0 if mbsmoke==1`があります。これは`rforestコマンド`の一種のバグへの対処です。

曝露群においてはite0が計算されておらず、欠損値です。ただ、rforestでは`if mbsmoke==0`により解析対象から曝露群が除外されています。

にも関わらず、rforestコマンドは、「`ite0`に欠損値があるためコマンドを実行できない！」というエラーを返してきます。

そこで「`rforest`の解析には使わないんだけれど、欠損値を埋める」という不毛なバグ対応を行っています。

```
* ***** ***** ***** ***** ***** ***** ***** ***** ***** ***** 
*
* 非曝露の学習：非曝露群における予測モデルの構築とそれを用いた予測
*
* ***** ***** ***** ***** ***** ***** ***** ***** ***** *****
* ----- ----- M_ITE0(X,T=0)の作成 ----- -----
replace ite0=0 if mbsmoke==1
rforest ite0 $xcate $xcont if mbsmoke==0, type(reg) seed(12345)
ereturn list

* ----- ----- M_ITE0の予測値を算出 ----- -----
predict pred_mite0
```

次に、曝露群データを用いて、予測変数Xを用いてITE1を予測するモデルを作ります。

```
* ***** ***** ***** ***** ***** ***** ***** ***** ***** ***** 
*
* 曝露の学習：非曝露群における予測モデルの構築とそれを用いた予測
*
* ***** ***** ***** ***** ***** ***** ***** ***** ***** *****
* ----- ----- M_ITE0(X,T=0)の作成 ----- -----
replace ite1=0 if mbsmoke==0
rforest ite1 $xcate $xcont if mbsmoke==1, type(reg) seed(12345)
ereturn list

* ----- ----- M_ITE0の予測値を算出 ----- -----
predict pred_mite1
```

ここまで計算できたので一旦様子を見てみましょう。

```
* ----- ----- 様子見 ----- -----
bys mbsmoke: su pred_mite* ite*
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/fa272969-06ff-4eb6-8c2e-1e8ae63ebb45)

非曝露群では`pred_mite0`と`ite0`の平均値がほぼ同じ値（-240）で、曝露群では`pred_mite1`と`ite1`の平均値がほぼ同じ値(-229）であることに注目して下さい。

これは当然の話で、非曝露群で言えばpred_mite0は非曝露群データでite0の値を予測しているものです。つまり、近い値になるようにモデルを構築したので、当然近い値になっている、というだけです。

## Second Stage（ウ）

最後に、**Second Stage（ウ）** に進みます。

まずは、傾向スコアを算出します。ロジスティック回帰モデルを採用しています。

```
* ----- ----- PS(X)の作成 ----- -----
logistic mbsmoke $xcate $xcont
predict ps, pr

bys mbsmoke: su ps
```

傾向スコアの値をみると下記の様になっています。

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/c100cf89-7586-4d77-9970-19b7afc9f0f6)

曝露群で傾向スコア（＝曝露する条件づき確率）が高くなっています。

最終段階として、この傾向スコアを利用した重み付き平均を取り、状況を確認します。

```
* ----- ----- 重み付き平均 ----- -----
gen cate = pred_mite0*ps + pred_mite1*(1-ps)


* ----- ----- 様子見 ----- -----
su cate
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/b2c8ea77-fd81-401e-b6ff-6471159ef4dd)

平均値が-239.12となりました。全体のCATE平均値なので、ATEと同じ物になります。

さて、今回は **CATE(age)** という「妊婦年齢で条件付けたATE」を求めたいのでした。

早速グラフ化してみます。近似曲線はこれまでと同様にFP(Fractional polynomial regression)という方法を採用しています。

```
* ----- ----- CATE(age)のグラフ ----- -----
twoway scatter cate mage, jitter(5) jitterseed(12345) mcolor(stblue%20) || fpfit cate mage, legend(label(1 "Scatter") label(2 "FP fit"))
```

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/821ce20e-1761-46ec-bde9-2c81fdfe6ab3)

これまで以上に、近似曲線から「右肩下がりだが、途中でフラットになる」という特徴がはっきりしました。

ためしに近似曲線を1つの座標にプロットしました。

![image](https://github.com/sankyoh/Stata_Lecture2023/assets/67684585/c866059f-813d-4746-a56d-7713911e45ba)

S-learnerだけ他2つから外れていることが分かります。特に、30歳超えたところからの上昇が始まっています。30歳を閾値とした何かの生物学的背景がないと、この案を採用するのは厳しそうです。

一方、T-learnerとX-learnerではそんなに違いがありません。ただし、T-learnerではITEの振れ幅が大きく、95%信頼区間を計算するときには広い区間になりそうです（95%信頼区間はブートストラップ法で計算します）。

そのため、今回の3つのLearnerのうちX-learnerが一番良さそうです。多くの場合でそうなるようです。

なお、X-learnerの近似曲線(Fractional polynomial regression)は、下記のような式になっています。

$$ CATE(age) = 2501.75 - 1728.32×ln(age) + 563.24×age^{-1} $$

# 次回
次回・未定（X-learnerの最適化？）
