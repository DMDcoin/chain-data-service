# chain-data-service

HTTP API for DMD Diamond chain data that can't be read efficiently from a node: staking history, epoch rewards and reward statistics, validator bonus scores and the DMD naming system (`.dmd` names). It also exposes the coin supply figures as public plain-text endpoints.

- Historical data is read from a PostgreSQL database that is filled by the chain indexer.
- Supply figures are read live from the chain over JSON-RPC.
- All endpoints except `/supply/*` require an API key. Requests are rate limited per key and per client IP, with the counters kept in Redis.

## Endpoints

### Supply (public)

Plain-text numbers in DMD, rate limited per IP.

| Endpoint | Returns |
|---|---|
| `GET /supply/maxcoins` | Maximum supply (4,380,000) |
| `GET /supply/circulating` | Maximum supply minus the delta and reinsert pots |
| `GET /supply/rewards` | Delta pot plus reinsert pot |
| `GET /supply/delta` | Delta pot of the block reward contract |
| `GET /supply/reinsert` | Reinsert pot of the block reward contract |
| `GET /supply/dao` | Governance pot plus the balance of the low-majority DAO |
| `GET /supply/staking` | Balance of the staking contract |
| `GET /supply/claiming` | Balance of the claiming pot |

### Validators

`:address` is the pool (staking) address of the validator.

| Endpoint | Returns |
|---|---|
| `GET /node/:address/bonus-score-history` | Bonus score over time; `includeReasons=true` adds the reason of each change |
| `GET /node/:address/bonus-score-reasons-history` | Every bonus score change with previous and new score and the reason |
| `GET /node/:address/stake-history` | Total stake of the pool over block ranges |
| `GET /node/:address/stake-transactions` | Stake, withdrawal and move events on the pool |
| `GET /node/:address/epoch-rewards` | Reward breakdown per epoch |
| `GET /node/:address/epoch-rewards/daily` | Rewards per UTC day; `range` is `30d` (default), `1y` or `all` |
| `GET /node/:address/reward-stats` | 30-day metrics: VOS30, RpT30, AEP30 and estimated APY |
| `POST /nodes/reward-stats` | The same metrics for up to 100 pools, body `{"addresses": [...]}` |

### Stakers

| Endpoint | Returns |
|---|---|
| `GET /staker/:address/stake-transactions` | Stake, withdrawal and move events of the address across all pools |
| `GET /staker/:address/rewards` | Delegator rewards per epoch and pool |
| `GET /staker/:address/reward-stats` | Rewards of the last 30 days and the number of active pools |
| `POST /stakers/reward-stats` | The same for up to 100 addresses, body `{"addresses": [...]}` |

### Names

| Endpoint | Returns |
|---|---|
| `GET /names` | Directory of registered names with search, status filter (`active`, `inactive`, `expired`, `blocked`), date ranges and sorting |
| `GET /names/blacklisted` | Names that are currently blocked |
| `GET /name/:label/history` | Creator, owner, status, event timeline and transfers of a name |
| `GET /owner/:address/names` | Names owned by an address |

List endpoints are paginated with `limit` and `offset`. The epoch and transaction endpoints can be filtered by epoch, block or time range; the accepted query parameters are listed next to each route in `src/routes`.

Responses are JSON, except for `/supply/*`. Invalid parameters are rejected with `403` and `{"message": "wrong-parameters"}`, a missing or unknown API key with `401`, and exceeded rate limits with `429` and a `Retry-After` header.

## Requirements

- Node.js 24
- PostgreSQL with the chain data schema, populated by the indexer. The service connects as the `diamond_api` role, which needs read access to the chain data tables and write access to `api_keys`.
- Redis, optional. Without it the rate limits are kept in memory per process.
- A JSON-RPC endpoint of the DMD Diamond network

## Configuration

Configuration is read from environment variables. `.env.example` contains a working set for local use.

| Variable | Default | Description |
|---|---|---|
| `PORT` | `4000` | HTTP port |
| `HOST` | `0.0.0.0` | Address the HTTP server binds to |
| `NODE_ENV` | | Set to `production` outside of development |
| `DMD_DB_API_HOST` | `db` | PostgreSQL host |
| `DMD_DB_API_PORT` | `5432` | PostgreSQL port |
| `DMD_DB_API_NAME` | `postgres` | Database name |
| `DMD_DB_API_USER` | `diamond_api` | Database role |
| `DMD_DB_API_PASS` | | Database password, required |
| `REDIS_URL` | `redis://localhost:6379` | Redis for the rate limit counters |
| `RPC_URL` | `http://localhost:8545` | JSON-RPC endpoint for `/supply/*` |
| `PUBLIC_RATE_LIMIT_PER_MINUTE` | `30` | Per-IP limit of the `/supply/*` endpoints |
| `AUTH_IP_RATE_LIMIT_PER_MINUTE` | `300` | Per-IP limit applied before API key authentication |

## Running

### Docker Compose

```bash
cp .env.example .env    # set DMD_DB_API_PASS and the database connection
docker compose up -d --build
```

This starts the API together with Redis. The API is published on `127.0.0.1:4000` only and is meant to be exposed through a reverse proxy.

If PostgreSQL runs in another Compose project, add the overlay that joins its network (name taken from `DB_NETWORK`, default `db_monitor-net`):

```bash
docker compose -f compose.yaml -f compose.db-network.yaml up -d --build
```

### From source

```bash
npm ci
set -a; source .env; set +a
npm run dev                 # restarts on changes
npm run build && npm start  # compiled build
```

### Container image

```bash
docker build -t chain-data-service .
```

The image contains the compiled application and its production dependencies only, runs as the unprivileged `node` user and works with a read-only root filesystem.

## API keys

Keys are sent as `Authorization: Bearer <key>` or `X-API-Key: <key>`. There are two kinds:

- `internal` keys for first-party frontends; requests must come with an allowed `Origin` or `Referer`.
- `external` keys for third parties, with their own per-minute and per-day limits.

Keys are stored as bcrypt hashes and managed with the bundled CLI. The key itself is printed only once, when it is generated.

```bash
docker compose exec api node dist/utils/keygen.js generate "Partner" external --rate-minute 100 --rate-day 50000
docker compose exec api node dist/utils/keygen.js list
docker compose exec api node dist/utils/keygen.js disable <key_id>
```

See [docs/api-authentication.md](docs/api-authentication.md) for details.

## Development

```bash
npm run typecheck
npm run build
```

CI runs the type check and build, then builds the container image and starts it with a read-only filesystem as a smoke test.

## License

[AGPL-3.0](LICENSE)
