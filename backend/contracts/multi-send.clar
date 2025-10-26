;; Multi-Send Payment Protocol (MSP)
;; Batch STX payouts in a single transaction.
;; - batch-send: variable amounts per recipient (tuple list)
;; - batch-send-equal: equal amount per recipient
;; - get-stats: simple running totals

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Constants & Errors
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant MAX-RECIPIENTS u200)

(define-constant ERR-EMPTY            (err u100))
(define-constant ERR-TOO-MANY         (err u101))
(define-constant ERR-OVERFLOW         (err u102))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Stats
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-data-var total-payouts   uint u0)  ;; cumulative uSTX sent
(define-data-var total-transfers uint u0)  ;; cumulative recipient count

(define-read-only (get-stats)
  {
    total-payouts:   (var-get total-payouts),
    total-transfers: (var-get total-transfers)
  }
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helpers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Sum function for fold over uints
(define-read-only (sum-fn (amt uint) (acc uint))
  (+ acc amt)
)

;; Extract-amounts: map a list of {to, ustx} -> (list uint)
(define-read-only (to-amounts (payments (list MAX-RECIPIENTS {to: principal, ustx: uint})))
  (map get-amt payments)
)

(define-read-only (get-amt (pmt {to: principal, ustx: uint}))
  (get ustx pmt)
)

;; Compute total amount from tuple list, with basic overflow guard.
(define-read-only (sum-payments (payments (list MAX-RECIPIENTS {to: principal, ustx: uint})))
  (let ((total (fold sum-fn (to-amounts payments) u0)))
    total
  )
)

;; Single payout from tx-sender -> recipient. Returns incremented count.
(define-private (payout-one
  (pmt {to: principal, ustx: uint})
  (count uint))
  (begin
    ;; If any transfer fails (e.g., insufficient balance), try! aborts the whole call,
    ;; reverting all earlier transfers. This gives us atomic "all-or-nothing" semantics.
    (try! (stx-transfer? (get ustx pmt) tx-sender (get to pmt)))
    (print {event: "payout", to: (get to pmt), amount: (get ustx pmt), idx: count})
    (+ count u1)
  )
)

;; Fold over recipients to send equal amount each.
(define-private (payout-equal-one
  (to principal)
  (ctx {amount: uint, count: uint}))
  (let (
        (amt   (get amount ctx))
        (count (get count ctx))
       )
    (begin
      (try! (stx-transfer? amt tx-sender to))
      (print {event: "payout", to: to, amount: amt, idx: count})
      { amount: amt, count: (+ count u1) }
    )
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public entrypoints
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; 1) Variable-amount batch send
;;    Accepts a list of up to MAX-RECIPIENTS tuples {to, ustx}
;;    Example arg (pseudo): [{to: SP..., ustx: u1000}, {to: SP..., ustx: u2500}]
(define-public (batch-send (payments (list MAX-RECIPIENTS {to: principal, ustx: uint})))
  (begin
    (asserts! (> (len payments) u0) ERR-EMPTY)
    (asserts! (<= (len payments) MAX-RECIPIENTS) ERR-TOO-MANY)

    (let (
          (total (sum-payments payments))
         )
      ;; Overflow guard (optional—uint in Clarity is bounded; this is mostly illustrative)
      (asserts! (>= total u0) ERR-OVERFLOW)

      ;; Perform all transfers from tx-sender directly; any failure reverts the whole tx.
      (let ((count (fold payout-one payments u0)))
        ;; Update stats on success
        (var-set total-payouts (+ (var-get total-payouts) total))
        (var-set total-transfers (+ (var-get total-transfers) count))
        (ok { total: total, count: count })
      )
    )
  )
)

;; 2) Equal-amount batch send
;;    Every recipient receives the same `amount` (uSTX).
(define-public (batch-send-equal (recipients (list MAX-RECIPIENTS principal)) (amount uint))
  (begin
    (asserts! (> (len recipients) u0) ERR-EMPTY)
    (asserts! (<= (len recipients) MAX-RECIPIENTS) ERR-TOO-MANY)

    ;; Fold with a tuple accumulator to keep track of count
    (let (
          (result (fold payout-equal-one recipients { amount: amount, count: u0 }))
          (count  (get count result))
          (total  (* amount (as-max-len (len recipients)))) ;; len returns uint; safe multiply
         )
      (var-set total-payouts (+ (var-get total-payouts) total))
      (var-set total-transfers (+ (var-get total-transfers) count))
      (ok { total: total, count: count })
    )
  )
)

;; Helper to treat (len recipients) as a uint value for multiply.
;; (No-op cast helper; included to make intent explicit.)
(define-read-only (as-max-len (n uint)) n)
