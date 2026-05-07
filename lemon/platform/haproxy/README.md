# HAProxy (lemon edge proxy)

OCI Network Load Balancer (NLB) の直下に立つ L4/L7 兼用フロントプロキシ。
クラスタ外から入ってくる全トラフィックの最前段で、以下を担当する。

- TCP のポート振り分け (LDAP/LDAPS, Minecraft, OTLP/Vault audit)
- HTTP / HTTPS の Traefik への中継 (PROXY protocol v2 で送出)
- IP ブロックリスト (`blocked-ips.txt`) による接続拒否
- IP 単位のレート制限 (HTTP: 10 req/s, HTTPS: 200 conn/60s)

## ファイル構成

| Path                      | 用途                                                          |
|---------------------------|-------------------------------------------------------------|
| `config/namespace.yaml`   | `haproxy` namespace                                         |
| `config/configmap.yaml`   | `haproxy.cfg` 本体 (ConfigMap, `kapp.k14s.io/versioned` 注釈付き) |
| `config/blocked-ips.yaml` | ブロック IP 一覧 (ConfigMap, 同 versioned)                         |
| `config/deployment.yaml`  | Deployment (replicas: 2, RollingUpdate, required podAntiAffinity) |
| `config/service.yaml`     | Service (`type: LoadBalancer`, OCI NLB)                     |

`kapp.k14s.io/versioned: ""` が付いている ConfigMap は kapp-controller が
中身を変更するたびに新しい名前で作り直し、Deployment の参照先も自動で
差し替える。これによって `haproxy.cfg` を編集すると Pod が rolling update
されて新しい設定が反映される。

## OCI NLB との連携

`Service` には以下の annotation を付けている:

- `oci-network-load-balancer.oraclecloud.com/is-preserve-source: "true"`
  クライアントの送信元 IP をバックエンドまで保つ。レート制限とブロック判定が
  実際のクライアント IP で動くために必須。
- `oci.oraclecloud.com/load-balancer-type: nlb`
- `externalTrafficPolicy: Local`
  Pod が動いている node にのみトラフィックを送るので、kube-proxy による
  追加 NAT が入らず送信元 IP が温存される。代わりに **Pod が居ない node には
  NLB が送らないように、healthCheckNodePort 経由のヘルスチェックが必要**
  (Kubernetes が自動で立てる、詳細は次節)。

### healthCheckNodePort の仕組み

`type: LoadBalancer` ＋ `externalTrafficPolicy: Local` の組み合わせで、
Kubernetes が **自動で** 採番する NodePort。`service.yaml` には書いていないが、
K8s が次のように埋めてくれる:

```sh
$ kubectl -n haproxy get svc haproxy -o jsonpath='{.spec.healthCheckNodePort}'
32699
```

各 worker node 上で kube-proxy がこの port (例: 32699) で小さな HTTP サーバを
立て、`/healthz` に「**この node に ready 状態の local endpoint が何個あるか**」
を返す:

- local に ready な pod がある node:
  ```
  HTTP/1.1 200 OK
  {"localEndpoints":1, ...}
  ```
- local に ready な pod が居ない node:
  ```
  HTTP/1.1 503 Service Unavailable
  {"localEndpoints":0, ...}
  ```

OCI Cloud Controller Manager は NLB を作るとき、各 worker node を backend set に
登録した上で、ヘルスチェックを `HTTP GET http://<nodeIP>:32699/healthz` に
設定する。NLB 側の挙動:

- **200** を返す node → トラフィックを送る
- **503** を返す node → 送らない

これによって「Local 配信なのに pod が居ない node に投げる」という穴が塞がる。

### rolling update における NLB 検知ラグの位置づけ

Pod が `Terminating` に入ると、EndpointSlice の ready 集合から即座に外れて
`:32699/healthz` が 503 を返し始める。ところが **NLB 側がそれを検知して
ルーティングを止めるまでにラグがある** (default 約 30 秒 = 10s × 3 retries)。

このラグ中に HAProxy が落ちてしまうと「NLB はまだ送るが受け手がいない」状態
になって RST が出る。だから preStop sleep 60s で HAProxy を生かして待ち、その
間に NLB に検知してもらう (後述の「NLB 検知遅延を吸収する graceful shutdown」)。

# Zero-downtime rolling update を実現する 4 つの仕組み

`kapp kick` や `kubectl rollout restart` で HAProxy Pod を rolling update
しても、外部クライアントが 1 件も落ちないことを目標にする。これを成立させる
ために以下の 4 つを **すべて同時に** 効かせる必要がある。1 つでも欠けると
落ちる。

## 1. NLB 検知遅延を吸収する graceful shutdown

`config/deployment.yaml` ＋ `config/configmap.yaml` (global)

```yaml
terminationGracePeriodSeconds: 130
lifecycle:
  preStop:
    exec:
      command: [ "/bin/sh", "-c", "sleep 60" ]
```

```haproxy
global
  hard-stop-after 60s
```

**狙い:** OCI NLB がこの node を「unhealthy」と判定する前に HAProxy が落ちると、
NLB はそのまま新規接続を流し続け、kube-proxy / HAProxy が応答できず RST に
なる。preStop で **60 秒間 HAProxy を生かしたまま待つ** ことで、その間に NLB
の `healthCheckNodePort` (約 30 秒で unhealthy 判定) がこの node を経路から
外し、新規接続は別 node に流れるようになる。

タイムライン:

![rolling-update timeline](./rolling-update-timeline.svg)

```
0s     Pod が Terminating, Endpoints から外れる
       → healthCheckNodePort が 503 を返し始める
0s     preStop 開始 (sleep 60) — HAProxy は通常稼働
~30s   OCI NLB がこの node を unhealthy と判断 → 新規接続が来なくなる
60s    preStop 完了 → SIGUSR1 → HAProxy soft-stop 開始
60-120s in-flight 接続を drain (hard-stop-after 60s)
120s   残接続を強制 close
130s   terminationGracePeriodSeconds 到達 (余裕 10s)
```

予算:
`preStop (60s) + hard-stop-after (60s) ≦ terminationGracePeriodSeconds (130s)`。
このどれかを変える時は他も連動させる。

## 2. ノードを偏らせない podAntiAffinity (required)

`config/deployment.yaml`

```yaml
strategy:
  rollingUpdate:
    maxSurge: 0
    maxUnavailable: 1
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: haproxy
            topologyKey: kubernetes.io/hostname
```

**狙い:** `externalTrafficPolicy: Local` の前提として、各 haproxy pod は
**別 node** に居る必要がある。同じ node に 2 個寄ると片方の node には local
endpoint が無くなり、その node に来たトラフィックは kube-proxy にドロップ
される。

`preferred` で済ませると、片方の node が CPU/メモリで詰まっている時に
scheduler が制約を無視して両方を空いている node に置く現象が起きる。
`required` で強制する。

ただし 2 node クラスタでは `required` antiAffinity と `maxSurge: 1` は両立
しない (3 個目の pod が「他の 2 個と別 node」を満たせず Pending する) ので、
更新戦略を `maxSurge: 0 / maxUnavailable: 1` に変更している:

```
[初期]   N1=oldA  N2=oldB
↓ oldA を Terminating → preStop 60s → drain
[T+130s] N1=空    N2=oldB                     ※ 1pod だけ稼働 (oldB)
↓ newA を N1 に schedule (antiAffinity OK)
[T+150s] N1=newA  N2=oldB
↓ oldB を Terminating → preStop 60s → drain
[T+280s] N1=newA  N2=空
↓ newB を N2 に schedule
[T+300s] N1=newA  N2=newB
```

「ready pod が 1 個になる窓」があるが、その間 Terminating 中の pod も
preStop sleep 60s の間は外部に対して稼働しているので、NLB は両 node 経由で
配信を続けられる。

## 3. probe 専用の health endpoint

`config/configmap.yaml`

```haproxy
frontend health_frontend
  bind *:8444
  mode http
  no log
  monitor-uri /healthz
```

`config/deployment.yaml`

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8444
readinessProbe:
  httpGet:
    path: /healthz
    port: 8444
```

**狙い:** kubelet probe を本番 listener (8443) と切り離す。本番 listener
には SNI inspect 待ち、レート制限、graceful shutdown による listen 停止
など、probe を「失敗」と誤判定させかねない要因が多い。誤判定で liveness
が落ちると pod が SIGKILL → 再作成され、せっかく整えた graceful shutdown
が無効化される。

専用 frontend は `monitor-uri` だけが反応するので、本番側の事情に巻き込ま
れず安定して 200 OK を返す。Service には公開していないので外部からは
見えない。

## 4. 内部 IP をレート制限から除外

`config/configmap.yaml` (HTTP/HTTPS frontend)

```haproxy
acl internal src 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.0/8
tcp-request connection track-sc0 src unless internal
tcp-request connection reject if !internal { sc_conn_rate(0) gt 200 }
```

**狙い:** HAProxy のレート制限は IP 単位だが、クラスタ内部から来るトラ
フィック (kubelet probe・他 pod のヘアピン経由・kapp-controller など) は
**送信元 IP が node IP や pod CIDR に集約される**。これらをまとめてカウント
すると簡単に閾値 (200 conn / 60s) を超え、内部の正規の通信が RST されて
pod の挙動が不安定になる。

RFC1918 (10/8, 172.16/12, 192.168/16) と loopback (127/8) を internal とみなし、
stick-table への記録自体スキップする。HAProxy 3 では同等の `unless` 構文。

# 試行錯誤メモ (補足)

最初からこの形だったわけではない。デバッグの過程で「これも踏んだ」という
ポイントを残す。同じ症状を見たら参考にしてほしい。

## preStop sleep は 5 秒では足りない

最初のバージョンは `preStop sleep 5` だった。OCI NLB の healthCheckNodePort
は default で 10s × 3 retries = 30s 程度かけて unhealthy 判定するので、
5 秒では到底間に合わず HAProxy が先に死んで RST が出ていた。
**40 秒に上げ、最終的に 60 秒で安定**。preStop は短くしすぎると意味が無い。

## レート制限の閾値 50/60s は厳しすぎた

旧設定: `tcp-request connection reject if { sc_conn_rate(0) gt 50 }`。
普通のブラウザでも 1 ページ表示で 30+ TCP 接続を開くので、ログイン中の
ユーザがちょっと回遊するだけで 50/分を超え、正規の通信が RST されていた。
**200/60s に緩和**。デバッグ中に curl ループで叩いて再現テストすると、
テストする自分自身がレート制限に引っかかるという罠もあった。

## TCP 8443 を probe するとレート制限以外の理由でも RST する

probe 用のソースを RFC1918 で除外しても、依然として 8443 への TCP probe
は時折 RST が返ってきた。理由を完全には特定していないが、本番 listener には
SNI inspect (`tcp-request inspect-delay 5s`) や soft-stop 中の listen close
など、probe を不安定にさせる要素が複数ある。**専用 health frontend
(8444 / `monitor-uri /healthz`) に切り出して根治**。

## podAntiAffinity preferred は守ってくれないことがある

ノードが 2 台で片方が CPU 過剰コミット (limit 合計 151%) の状態だと、
scheduler は `preferred` を平気で無視して空いている方に 2 個積んでしまう。
そうなると `externalTrafficPolicy: Local` で片肺になる。`required` ＋
`maxSurge: 0` の組み合わせに変更して回避。

## kapp-controller / `kubectl rollout` の挙動の違い

- `kubectl rollout status` は **新しい replica が ready になった瞬間**に
  「成功」を返してくる。古い pod がまだ Terminating 中でもこれが返るので、
  完了したと思って次のテストを始めると preStop drain 中の trafic に当たる。
- 確実に「全部入れ替わった」を待つには
  `kubectl get pods -n haproxy` で Terminating が 0 になることを確認する。

## ブロック IP の運用

`config/blocked-ips.yaml` に CIDR を追記すると、HAProxy は
`acl blocked src -f /usr/local/etc/haproxy/blocked-ips.txt` で参照して
TCP コネクションを reject する。HTTPS frontend と HTTP frontend の両方で
有効。設定変更は ConfigMap 更新 → versioned により Pod が rolling update
されて反映される。

ブロック追加は通常 `access-monitor` 関連の自動化フローで行われる
(`Block <ip> via access-monitor` というコミットが履歴に並んでいる)。

# 動作確認

```sh
# Pod ログでアクセスログを見る
kubectl --context lemon -n haproxy logs -l app=haproxy -f

# rolling update 中の通信断確認 (別ターミナルで)
# レート制限を踏まないペース (2s 間隔) で叩く
while true; do
  curl -sk -m 4 -o /dev/null -w "%{http_code}\n" https://ik.am/
  sleep 2
done
# 全部 200 が出ること (000 や Connection reset by peer が出ないこと)

# pod が偏ってないか
kubectl --context lemon -n haproxy get pods -o wide
# NODE 列が異なる 2 つになっていること

# probe 由来の再起動が起きていないか
kubectl --context lemon -n haproxy get pods
# RESTARTS 列が 0 のまま安定していること
```
