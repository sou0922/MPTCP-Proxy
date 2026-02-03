# MPTCP-Proxy テストスイート解説

## MPTCP（Multipath TCP）技術について

### MPTCPとは

Multipath TCP（MPTCP）は、TCPプロトコルの拡張仕様であり、単一のTCP接続で複数のネットワークパスを同時に使用できるようにする技術です。RFC 6824として標準化されており、従来のTCPとの互換性を保ちながら、複数のネットワークインターフェースを活用できます。

### MPTCPの主な利点

1. **帯域幅の集約**
   - 複数のネットワークパス（例：Wi-FiとLTE）の帯域幅を合算
   - 合計スループットの向上が可能
   - iperf3テストでは、複数パスを使うことで転送速度が向上

2. **耐障害性の向上**
   - 一つのパスが切断されても他のパスで通信を継続
   - シームレスなフェイルオーバー
   - モバイル環境での接続の安定性向上

3. **レイテンシの最適化**
   - 複数パスから最適な経路を選択
   - ネットワーク状況に応じた動的な経路変更

### MPTCP の仕組み

#### 1. 接続確立（Connection Establishment）

```
Client                                Server
  |                                      |
  |------- SYN + MP_CAPABLE ----------->|  初期サブフロー確立
  |<------ SYN/ACK + MP_CAPABLE --------|
  |------- ACK ------------------------>|
  |                                      |
```

- `MP_CAPABLE`オプションでMPTCP対応を通知
- 最初のサブフロー（subflow）でメイン接続を確立
- トークン交換で接続を識別

#### 2. アドレス通知（Address Advertisement）

```
  |<------ ACK + ADD_ADDR --------------|  追加アドレスを通知
  |                                      |
```

- `ADD_ADDR`オプションで追加のIPアドレスを通知
- サーバーまたはクライアントが複数のIPアドレスを持つことを相手に伝える
- テストでは`ip mptcp endpoint add`コマンドで設定

#### 3. サブフロー確立（Subflow Establishment）

```
  |------- SYN + MP_JOIN -------------->|  新しいサブフロー
  |<------ SYN/ACK + MP_JOIN -----------|
  |------- ACK ------------------------>|
  |                                      |
```

- `MP_JOIN`オプションで既存のMPTCP接続に新しいサブフローを追加
- 各サブフローは独立したTCP接続として動作
- トークンで同じMPTCP接続であることを識別

#### 4. データ転送（Data Transfer）

- 各サブフローで並列にデータを送信
- データにはData Sequence Number（DSN）を付与
- 受信側でシーケンス番号を使って正しい順序に再構築
- 輻輳制御は各サブフロー独立して実行

#### 5. 接続終了（Connection Termination）

```
  |------- DATA_FIN -------------------->|
  |<------ DATA_ACK ---------------------|
  |                                       |
```

- 各サブフローを個別に終了
- `DATA_FIN`でMPTCP接続全体を終了

### MPTCP イベントの意味

テストで監視される主なイベント：

- **CREATED**: MPTCP接続が作成された
- **ESTABLISHED**: メインのサブフローが確立された
- **ANNOUNCED**: 追加のIPアドレスが通知された（ADD_ADDRイベント）
- **SF_ESTABLISHED**: 新しいサブフローが確立された（Subflow Established）
- **CLOSED**: 接続が閉じられた

### MPTCP設定コマンド

```bash
# サブフローの数を制限
ip mptcp limits set subflow 1

# エンドポイントを追加（signal mode）
ip mptcp endpoint add 10.0.0.2 dev eth1 signal

# エンドポイントを追加（subflow mode）
ip mptcp endpoint add 10.0.0.3 dev eth1 subflow

# 受信するアドレス通知の数を設定
ip mptcp limits set add_addr_accepted 1

# MPTCP状態を監視
ip mptcp monitor
```

**モードの違い：**
- `signal`: このアドレスをADD_ADDRで相手に通知する（受動的）
- `subflow`: このアドレスから積極的にサブフローを確立する（能動的）

---

## テストシナリオ解説

### 1. Simple Test (`test/simple/`)

#### 目的
MPTCPの基本的な機能を検証する最もシンプルなテストシナリオです。2つの独立したネットワークパスを使用して、MPTCP接続の確立、サブフローの作成、データ転送、接続終了までの一連の流れを確認します。

#### ネットワーク構成

```
┌─────────────────┐                    ┌─────────────────┐
│     Client      │                    │     Server      │
│                 │                    │                 │
│ mptcp-proxy     │                    │  mptcp-proxy    │
│ (client mode)   │                    │ (server mode)   │
│   :5555         │                    │    :4444        │
└─────────────────┘                    └─────────────────┘
       │ eth0 (10.123.200.3)                │ eth0 (10.123.200.2)
       └──────────┬────────────────────────┬┘
                  │   Network A            │
                  │  10.123.200.0/24       │
                  └────────────────────────┘
       
       │ eth1 (10.123.201.3)                │ eth1 (10.123.201.2)
       └──────────┬────────────────────────┬┘
                  │   Network B            │
                  │  10.123.201.0/24       │
                  └────────────────────────┘
```

#### データフロー

1. クライアントでiperf3が`localhost:5555`に接続
2. クライアントのmptcp-proxy（client mode）が接続を受け付け
3. mptcp-proxyがMPTCP接続をサーバー`10.123.200.2:4444`に確立
4. サーバーのmptcp-proxy（server mode）がMPTCP接続を受け付け
5. サーバーのmptcp-proxyが通常のTCP接続でiperf3サーバー（`localhost:5201`）に転送
6. データ転送開始

#### MPTCP動作

1. **初期接続**: Network A経由でメインサブフロー確立
2. **アドレス通知**: サーバーがeth1のアドレス（10.123.201.2）を`ADD_ADDR`で通知
3. **サブフロー確立**: クライアントがNetwork B経由で2つ目のサブフロー確立
4. **データ転送**: 両方のサブフローで並列にデータ転送
5. **接続終了**: 両サブフローを終了

#### 期待される結果

- `CREATED`: 2回（双方向のMPTCP接続）
- `ESTABLISHED`: 2回（初期サブフロー確立）
- `ANNOUNCED`: 2回（両側がアドレス通知）
- `SF_ESTABLISHED`: 2回（追加サブフロー確立）
- `CLOSED`: 2回（接続終了）

#### 実行方法

```bash
cd test/simple
./test.sh
```

---

### 2. Routing Test (`test/routing/`)

#### 目的
ルーターを介した環境でのMPTCPの動作を検証します。特に、ECMP（Equal-Cost Multi-Path）ルーティングとMPTCPの組み合わせにより、異なるネットワークパスを経由したデータ転送が正しく行われるかを確認します。

#### ネットワーク構成

```
┌─────────────────┐          ┌─────────────────┐          ┌─────────────────┐
│     Client      │          │     Router      │          │     Server      │
│                 │          │                 │          │                 │
│ mptcp-proxy     │          │  (forwarding)   │          │  mptcp-proxy    │
│ (client mode)   │          │                 │          │ (server mode)   │
│   :5555         │          │                 │          │    :4444        │
└─────────────────┘          └─────────────────┘          └─────────────────┘
       │ eth0                     │ eth2              eth0 │ eth0
       │ (10.123.202.3)           │ (10.123.202.2)        │ (10.123.200.2)
       │                          │                        │
       └────────┬─────────────────┘                        │
                │  Network C                               │
                │  10.123.202.0/24                         │
                └──────────────────────────────────────────┘
                                                            │ eth1
                           ┌──────────────────┬─────────────┘ (10.123.201.2)
                           │ Network A        │ Network B      
                           │ 10.123.200.0/24  │ 10.123.201.0/24
                           │                  │
                      eth0 │             eth1 │
                     (10.123.200.3)    (10.123.201.3)
                           └────────┬─────────┘
                                    │
                                 Router
```

#### ルーティング設定

**サーバー側（ECMP）:**
```bash
# 2つのネクストホップを持つマルチパスルーティング
ip route add 10.123.202.0/24 \
    nexthop via 10.123.200.3 weight 1 \
    nexthop via 10.123.201.3 weight 1
```

この設定により、サーバーからクライアントへのパケットは2つのルーター経由でラウンドロビンまたはハッシュベースで分散されます。

**クライアント側:**
```bash
# 静的ルート設定
ip route add 10.123.200.0/24 via 10.123.202.2
ip route add 10.123.201.0/24 via 10.123.202.2
```

#### データフロー

1. クライアントからサーバーへの接続はルーター経由
2. ルーターが両方向のトラフィックを転送
3. MPTCPはルーターを透過的に通過
4. サーバーのECMP設定により、戻りトラフィックが複数パスに分散

#### MPTCP動作の特徴

- ルーターはMPTCPを認識せず、通常のTCPパケットとして転送
- MPTCPのサブフローは異なる経路を通る可能性がある
- ルーターのNAT/ファイアウォールがある場合は追加の考慮が必要

#### 期待される結果

simpleテストと同じ：
- `CREATED`: 2回
- `ESTABLISHED`: 2回  
- `ANNOUNCED`: 2回
- `SF_ESTABLISHED`: 2回
- `CLOSED`: 2回

#### 実行方法

```bash
cd test/routing
./test.sh
```

---

### 3. Routing2 Test (`test/routing2/`)

#### 目的
非対称なMPTCP構成を検証します。サーバー側は単一のネットワークインターフェースのみを持ち、クライアント側だけが複数のネットワークパスを持つシナリオです。これは、サーバーが固定IPアドレスを持ち、クライアントが複数の接続手段（例：Wi-FiとLTE）を持つモバイル環境を模擬します。

#### ネットワーク構成

```
┌─────────────────┐          ┌─────────────────┐          ┌─────────────────┐
│     Server      │          │     Router      │          │     Client      │
│                 │          │                 │          │                 │
│ mptcp-proxy     │          │  (forwarding)   │          │  mptcp-proxy    │
│ (server mode)   │          │                 │          │ (client mode)   │
│   :4444         │          │                 │          │    :5555        │
└─────────────────┘          └─────────────────┘          └─────────────────┘
       │ eth0                eth0 │                 eth1 │ eth0        eth1 │
       │ (10.123.200.2)          │                      │ (10.123.201.3) (10.123.202.3)
       │                         │                      │
       └───────┬─────────────────┘                      │
               │  Network A                             │
               │  10.123.200.0/24                       │
               └────────────────────────────────────────┘
                          │ eth1                 eth0 │
                          │ (10.123.201.2)           │
                          │                           │
                          └───────┬───────────────────┘
                                  │  Network B
                                  │  10.123.201.0/24
                                  └───────────────────
                          
                          │ eth2                 eth1 │
                          │ (10.123.202.2)           │
                          │                           │
                          └───────┬───────────────────┘
                                  │  Network C
                                  │  10.123.202.0/24
                                  └───────────────────
```

#### 重要な設定の違い

**サーバー側:**
```bash
ip mptcp limits set subflow 1
# エンドポイント追加なし（ADD_ADDRを送信しない）
```

**クライアント側:**
```bash
ip mptcp limits set subflow 1 add_addr_accepted 1
# subflowモードでエンドポイント追加（能動的にサブフロー確立）
ip mptcp endpoint add 10.123.202.3 dev eth1 subflow
```

#### MPTCP動作の特徴

1. **初期接続**: クライアントのeth0から接続開始
2. **アドレス通知なし**: サーバーは追加アドレスを持たないため`ADD_ADDR`を送信しない
3. **クライアント主導**: クライアントが`subflow`モード設定により、eth1から2つ目のサブフローを自発的に確立
4. **非対称構成**: サーバーは単一パス、クライアントは複数パス

#### 実世界での応用例

- モバイルクライアント（Wi-Fi + LTE）とデータセンターのサーバー
- マルチホームクライアントと単一IPサーバー
- ロードバランサー背後のサーバーとの通信

#### 期待される結果

- `CREATED`: 2回
- `ESTABLISHED`: 2回
- `ANNOUNCED`: **0回**（サーバーが通知しない）
- `SF_ESTABLISHED`: 2回（クライアントが能動的に確立）
- `CLOSED`: 2回

#### 実行方法

```bash
cd test/routing2
./test.sh
```

---

### 4. SoftEther VPN Test (`test/sevpn/`)

#### 目的
VPNトンネルとMPTCPを組み合わせた、最も複雑で実用的なシナリオを検証します。VPN接続の信頼性をMPTCPで向上させ、複数のネットワークパス経由でVPNトンネルを維持します。

#### ネットワーク構成

```
クライアント側:
┌──────────────┐     ┌──────────────┐
│  client-vpn  │────▶│client-proxy  │
│  VPNクライアント│     │ MPTCP proxy  │
│ 10.101.0.3   │     │ (client mode)│
└──────────────┘     │ 10.101.0.2   │
                     │ 10.102.0.3   │ eth0 (Network A)
                     │ 10.102.1.3   │ eth1 (Network B)
                     └──────────────┘
                            │
                            │ MPTCP接続
                            │
サーバー側:                  ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  server-srv  │◀────│ server-vpn   │◀────│server-proxy  │
│ 実サーバー     │     │ VPNサーバー   │     │ MPTCP proxy  │
│ 10.100.1.3   │     │ 10.100.0.3   │     │ (server mode)│
└──────────────┘     │ 10.100.1.2   │     │ 10.100.0.2   │
                     └──────────────┘     │ 10.102.0.2   │ eth0 (Network A)
                                          │ 10.102.1.2   │ eth1 (Network B)
                                          └──────────────┘
```

#### データフロー（レイヤー別）

**アプリケーション層の視点:**
```
client-vpn → VPNトンネル → server-vpn → server-srv
  ping        (暗号化)       (復号化)      応答
```

**ネットワーク層の視点:**
```
client-vpn → client-proxy → (MPTCP/複数パス) → server-proxy → server-vpn → server-srv
            VPNパケット        Network A/B         VPNパケット
            カプセル化          並列転送            デカプセル化
```

#### コンポーネントの役割

1. **client-vpn**: SoftEther VPNクライアント
   - VPNトンネルを確立
   - アプリケーション（ping）を実行

2. **client-proxy**: MPTCP proxy（クライアントモード）
   - VPNトラフィックをMPTCP化
   - 2つのネットワークインターフェース経由で送信

3. **server-proxy**: MPTCP proxy（サーバーモード）  
   - MPTCP接続を受信
   - 通常のTCP接続でVPNサーバーに転送

4. **server-vpn**: SoftEther VPNサーバー
   - VPNトンネルを終端
   - パケットを復号化してserver-srvに転送

5. **server-srv**: 実際のサーバー
   - pingリクエストに応答

#### MPTCP + VPNの利点

1. **VPN接続の高可用性**
   - 一つのネットワークパスが切断されてもVPN接続継続
   - モバイル環境での接続安定性向上

2. **帯域幅の集約**
   - 複数回線の帯域を合算してVPNスループット向上
   - 大容量ファイル転送の高速化

3. **遅延の最適化**
   - 複数パスから低遅延パスを動的に選択
   - リアルタイム通信の品質向上

#### 設定のポイント

**待機時間の調整:**
```bash
sleep 10  # VPNサーバーの起動に時間がかかるため長めに待機
```

**テストコマンド:**
```bash
# iperf3ではなくpingを使用（VPN経由の疎通確認）
docker compose exec client-vpn ping 10.100.1.3 -c 5
```

#### 期待される結果

- `CREATED`: 2回
- `ESTABLISHED`: 2回
- `ANNOUNCED`: 2回
- `SF_ESTABLISHED`: 2回
- `CLOSED`: 監視されない（VPN接続の複雑さのため一部イベントが追跡困難）

#### 実行方法

```bash
cd test/sevpn
./test.sh
```

**注意**: このテストは起動に時間がかかります（VPN初期化のため）。

---

## 全テストの比較表

| 項目 | Simple | Routing | Routing2 | SoftEther VPN |
|------|--------|---------|----------|---------------|
| **複雑度** | ⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **ノード数** | 2 | 3 | 3 | 5 |
| **ネットワーク数** | 2 | 3 | 3 | 5 |
| **ルーター** | なし | あり | あり | なし |
| **VPN** | なし | なし | なし | SoftEther |
| **ECMP** | なし | あり | なし | なし |
| **サーバーANNOUNCED** | あり | あり | なし | あり |
| **テストツール** | iperf3 | iperf3 | iperf3 | ping |
| **起動時間** | 3秒 | 5秒 | 5秒 | 10秒 |
| **主な検証内容** | 基本動作 | ルーティング | 非対称構成 | VPN統合 |

---

## テスト実行のベストプラクティス

### 1. 環境要件の確認

```bash
# Linux カーネルバージョン確認（5.15以上推奨）
uname -r

# MPTCPサポート確認
cat /proc/sys/net/mptcp/enabled

# Docker確認
docker --version
docker compose version
```

### 2. クリーンな環境で実行

```bash
# 既存コンテナの完全削除
docker compose down -v

# イメージキャッシュのクリア（必要に応じて）
docker system prune -af
```

### 3. ログの確認

```bash
# テスト実行中のログ確認
docker compose logs -f

# 特定コンテナのログ
docker compose logs client
docker compose logs server

# MPTCPイベントの詳細確認
docker compose exec client ip mptcp monitor
```

### 4. トラブルシューティング

**問題: iperf3でエラー発生**
```bash
# IPv4を明示的に指定
iperf3 -c localhost -p 5555 -4

# iperf3サーバーの状態確認
docker compose exec server ps aux | grep iperf3
docker compose exec server netstat -tlnp | grep 5201
```

**問題: サブフローが確立されない**
```bash
# MPTCP設定確認
docker compose exec client ip mptcp endpoint show
docker compose exec client ip mptcp limits show

# ルーティングテーブル確認
docker compose exec client ip route show
```

**問題: コンテナが起動しない**
```bash
# コンテナログ確認
docker compose logs

# リソース確認
docker stats

# ネットワーク確認
docker network ls
docker network inspect <network_name>
```

---

## まとめ

これらのテストスイートは、MPTCPとMPTCP-Proxyの機能を段階的に検証します：

1. **Simple**: 基本的なMPTCP動作の理解
2. **Routing**: ルーティング環境での動作確認
3. **Routing2**: 実用的な非対称構成の検証
4. **SoftEther VPN**: 実運用シナリオのシミュレーション

各テストは独立して実行可能で、自動的にクリーンアップされるため、繰り返しテストが容易です。MPTCPの理解を深め、実際のデプロイメントに向けた検証に活用できます。