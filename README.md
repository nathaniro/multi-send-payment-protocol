# Multi‑Send Payment Protocol (MSP)

Clarity-powered batch payouts for STX. Send to up to 200 recipients in a single atomic transaction, track simple stats, and use a lightweight React + Vite + Tailwind frontend for CSV-driven sends.

This repo contains:
- backend/ — Clarity smart contract, Clarinet config, and tests
- frontend/ — Vite + React UI (CSV upload, review table, and send form)


## Features

- Batch send with variable amounts per recipient (`batch-send`)
- Batch send with equal amounts to a recipient list (`batch-send-equal`)
- Atomic execution: if any transfer fails, the whole tx reverts
- Simple on-chain stats via `get-stats` (`total-payouts`, `total-transfers`)
- CSV upload in the UI; preview recipients and amounts before sending


## Architecture

- Smart contract: `backend/contracts/multi-send.clar`
	- Constant limit: `MAX-RECIPIENTS = 200`
	- Public entrypoints:
		- `batch-send (payments (list 200 {to: principal, ustx: uint}))`
		- `batch-send-equal (recipients (list 200 principal)) (amount uint)`
	- Read-only:
		- `get-stats -> { total-payouts: uint, total-transfers: uint }`
	- Events: emits a lightweight `print` per payout `{event: "payout", to, amount, idx}`

- Frontend: `frontend/`
	- CSV parsing: `papaparse`
	- Connectivity: `@stacks/connect`, `@stacks/transactions`
	- Styling: `tailwindcss`


## Contract API

Inputs and types (Clarity):

- `batch-send (payments (list 200 {to: principal, ustx: uint}))`
	- Each tuple contains a recipient principal and a micro-STX amount (`ustx`).
	- Returns: `(ok { total: uint, count: uint })` or `(err ...)` on failure.

- `batch-send-equal (recipients (list 200 principal)) (amount uint)`
	- Sends the same `amount` of micro-STX to each recipient.
	- Returns: `(ok { total: uint, count: uint })`.

- `get-stats`
	- Read-only; returns cumulative totals since contract deployment.

Important notes:
- The entrypoint types use literal list lengths (e.g., `list 200`) to satisfy Clarity’s type system.
- All amounts are in micro‑STX (uSTX). 1 STX = 1_000_000 uSTX.


## CSV format (for the UI)

Upload a CSV with headers:

```
address,amount
SP3FBR2AGKX32EMRA9GZ6KGS0NAEK40C54N9PZ6GZ,10
SP2C2M8N2ZB5J4J8W5EG0XK2C4RMN8ZQGQ4S6G6X0,2.5
```

- `address`: Stacks principal (SP…/ST…)
- `amount`: Amount in STX (the UI converts to uSTX internally)


## Quickstart

Prerequisites:
- Node.js 18+ and npm
- Clarinet (for contract checks): https://docs.hiro.so/clarinet

Clone and install:

```bash
# Backend
cd backend
npm install

# Frontend
cd ../frontend
npm install
```

Run the contract checks:

```bash
cd ../backend
clarinet check
```

Run backend tests (Vitest):

```bash
cd backend
npm test
```

Start the frontend:

```bash
cd frontend
npm run dev
```


## Frontend configuration

Create a `.env` file in `frontend/` with the deployed contract info:

```
VITE_CONTRACT_ADDRESS=SPXXXXXXXXXXXXXXX...   # contract deployer address
VITE_CONTRACT_NAME=multi-send                # contract name
```

By default, the UI uses `StacksTestnet` in `SendForm.tsx`. Update the network in code if you need Devnet/Mainnet.


## Using Clarinet console (examples)

Open the console:

```bash
cd backend
clarinet console
```

Inside the REPL:

```lisp
;; Variable-amount batch send (amounts in uSTX)
(contract-call? .multi-send batch-send
	(list
		{ to: 'SP3FBR2AGKX32EMRA9GZ6KGS0NAEK40C54N9PZ6GZ, ustx: u1000000 }
		{ to: 'SP2C2M8N2ZB5J4J8W5EG0XK2C4RMN8ZQGQ4S6G6X0, ustx: u2500000 }
	)
	tx-sender)

;; Equal-amount batch send: 2 STX each (2_000_000 uSTX)
(contract-call? .multi-send batch-send-equal
	(list 'SP3FBR2AGKX32EMRA9GZ6KGS0NAEK40C54N9PZ6GZ 'SP2C2M8N2ZB5J4J8W5EG0XK2C4RMN8ZQGQ4S6G6X0)
	u2000000
	tx-sender)

;; Read stats
(contract-call-read-only? .multi-send get-stats () tx-sender)
```


## Deploying

Clarinet network settings live in `backend/settings/`:
- `Devnet.toml`, `Testnet.toml`, `Mainnet.toml`

Example (Testnet) flow:
1) Configure keys in `settings/Testnet.toml`.
2) Build and check locally: `clarinet check`.
3) Deploy with Clarinet or your preferred Stacks deployment flow.
4) Point the frontend `.env` at the deployed address/name.


## Security and limits

- Max recipients per call: 200
- All transfers are from `tx-sender`
- Atomic semantics: any failure reverts all transfers
- On-chain stats are non-authoritative (for convenience/UX only)


## Troubleshooting

- Clarity: “supplied type description is invalid”
	- Ensure list lengths in type annotations use literals: `(list 200 …)`, not a constant.

- Clarity: “illegal non-ASCII character”
	- Use plain ASCII in comments/strings; replace fancy dashes/quotes.

- Frontend args mismatch
	- Contract expects `{to, ustx}` for `batch-send`. Ensure your client constructs tuples with `ustx` (micro‑STX), not `amount`.


## Repo map

- `backend/contracts/multi-send.clar` — MSP contract
- `backend/tests/multi-send.test.ts` — Vitest harness (extend with real tests)
- `backend/settings/*.toml` — network configs
- `frontend/src` — React app (CSV, table, form)


## License

MIT

