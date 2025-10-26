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
(define-read-only (to-amounts (payments (list 200 {to: principal, ustx: uint})))
  (map get-amt payments)
)

(define-read-only (get-amt (pmt {to: principal, ustx: uint}))
  (get ustx pmt)
)

;; Compute total amount from tuple list, with basic overflow guard.
(define-read-only (sum-payments (payments (list 200 {to: principal, ustx: uint})))
  (let ((total (fold sum-fn (to-amounts payments) u0)))
    total
  )
)

;; Single payout from tx-sender -> recipient.
;; Accumulator is a response carrying the count so failures can abort the whole tx.
(define-private (payout-one
  (pmt {to: principal, ustx: uint})
  (acc (response uint uint)))
  (match acc ok-count
    (match (stx-transfer? (get ustx pmt) tx-sender (get to pmt)) ok-tx
      (begin
        (print {event: "payout", to: (get to pmt), amount: (get ustx pmt), idx: ok-count})
        (ok (+ ok-count u1))
      )
      tx-err
      (err tx-err)
    )
    acc-err
    (err acc-err)
  )
)

;; Fold over recipients to send equal amount each.
(define-private (payout-equal-one
  (to principal)
  (ctx { amount: uint, count: (response uint uint) }))
  (let (
        (amt (get amount ctx))
        (res (get count ctx))
       )
    (match res ok-count
      (match (stx-transfer? amt tx-sender to) ok-tx
        (begin
          (print {event: "payout", to: to, amount: amt, idx: ok-count})
          { amount: amt, count: (ok (+ ok-count u1)) }
        )
        tx-err
        { amount: amt, count: (err tx-err) }
      )
      acc-err
      { amount: amt, count: (err acc-err) }
    )
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public entrypoints
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; 1) Variable-amount batch send
;;    Accepts a list of up to MAX-RECIPIENTS tuples {to, ustx}
;;    Example arg (pseudo): [{to: SP..., ustx: u1000}, {to: SP..., ustx: u2500}]
(define-public (batch-send (payments (list 200 {to: principal, ustx: uint})))
  (begin
    (asserts! (> (len payments) u0) ERR-EMPTY)
    (asserts! (<= (len payments) MAX-RECIPIENTS) ERR-TOO-MANY)

    (let (
          (total (sum-payments payments))
         )
      ;; Overflow guard (optional - uint in Clarity is bounded; this is mostly illustrative)
      (asserts! (>= total u0) ERR-OVERFLOW)

      ;; Perform all transfers from tx-sender directly; any failure reverts the whole tx.
      (let ((result (fold payout-one payments (ok u0))))
        (let ((count (try! result)))
          ;; Update stats on success
          (var-set total-payouts (+ (var-get total-payouts) total))
          (var-set total-transfers (+ (var-get total-transfers) count))
          (ok { total: total, count: count })
        )
      )
    )
  )
)

;; 2) Equal-amount batch send
;;    Every recipient receives the same `amount` (uSTX).
(define-public (batch-send-equal (recipients (list 200 principal)) (amount uint))
  (begin
    (asserts! (> (len recipients) u0) ERR-EMPTY)
    (asserts! (<= (len recipients) MAX-RECIPIENTS) ERR-TOO-MANY)

    ;; Fold with a tuple accumulator to keep track of count (as a response)
    (let (
          (result (fold payout-equal-one recipients { amount: amount, count: (ok u0) }))
          (count  (try! (get count result)))
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
