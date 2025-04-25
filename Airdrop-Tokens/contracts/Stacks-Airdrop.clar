;; Token Airdrop Distribution Smart Contract
;;
;; A Clarity smart contract that manages token airdrops to eligible recipients.
;; Features include:
;; - Managing eligible recipient addresses
;; - Token claim functionality with eligibility verification
;; - Administrator controls for distribution parameters
;; - Reclaiming unclaimed tokens after a specified period
;; - Event logging for important contract actions

;; Define admin constants
(define-constant admin-address tx-sender)

;; Define error constants
(define-constant ERR-ADMIN-ONLY (err u100))
(define-constant ERR-TOKENS-ALREADY-CLAIMED (err u101))
(define-constant ERR-USER-NOT-ELIGIBLE (err u102))
(define-constant ERR-TOKEN-SHORTAGE (err u103))
(define-constant ERR-DISTRIBUTION-PAUSED (err u104))
(define-constant ERR-INVALID-TOKEN-AMOUNT (err u105))
(define-constant ERR-RECLAIM-TIMING-INVALID (err u106))
(define-constant ERR-RECIPIENT-EXISTS (err u107))
(define-constant ERR-TIMEFRAME-INVALID (err u108))

;; Define airdrop state variables
(define-data-var distribution-active bool true)
(define-data-var tokens-sent-total uint u0)
(define-data-var reward-size uint u100)
(define-data-var launch-block uint block-height)
(define-data-var lockup-duration uint u10000) ;; Block count before unclaimed tokens can be reclaimed

;; Define recipient tracking maps
(define-map whitelist principal bool)
(define-map claim-ledger principal uint)

;; Define the token to be distributed
(define-fungible-token reward-token)

;; Event tracking system
(define-data-var event-id-counter uint u0)
(define-map event-history uint {event-type: (string-ascii 20), event-data: (string-ascii 256)})

;; Record an event in the contract history
(define-private (log-transaction (event-type (string-ascii 20)) (event-data (string-ascii 256)))
  (let ((current-id (var-get event-id-counter)))
    (map-set event-history current-id {event-type: event-type, event-data: event-data})
    (var-set event-id-counter (+ current-id u1))
    current-id))

;; ADMINISTRATION FUNCTIONS

;; Register a new eligible recipient
(define-public (whitelist-address (user principal))
  (begin
    (asserts! (is-eq tx-sender admin-address) ERR-ADMIN-ONLY)
    (asserts! (is-none (map-get? whitelist user)) ERR-RECIPIENT-EXISTS)
    (log-transaction "whitelist-add" "user added to whitelist")
    (ok (map-set whitelist user true))))

;; Remove a previously eligible recipient
(define-public (remove-from-whitelist (user principal))
  (begin
    (asserts! (is-eq tx-sender admin-address) ERR-ADMIN-ONLY)
    (asserts! (is-some (map-get? whitelist user)) ERR-USER-NOT-ELIGIBLE)
    (log-transaction "whitelist-remove" "user removed from whitelist")
    (ok (map-delete whitelist user))))

;; Register multiple recipients at once
(define-public (batch-whitelist (users (list 200 principal)))
  (begin
    (asserts! (is-eq tx-sender admin-address) ERR-ADMIN-ONLY)
    (log-transaction "batch-whitelist" "multiple users whitelisted")
    (ok (map whitelist-address users))))

;; Change the token amount per recipient
(define-public (change-reward-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender admin-address) ERR-ADMIN-ONLY)
    (asserts! (> new-amount u0) ERR-INVALID-TOKEN-AMOUNT)
    (var-set reward-size new-amount)
    (log-transaction "reward-updated" "token reward amount changed")
    (ok new-amount)))

;; Adjust the reclaim waiting period
(define-public (update-lockup-period (new-duration uint))
  (begin
    (asserts! (is-eq tx-sender admin-address) ERR-ADMIN-ONLY)
    (asserts! (> new-duration u0) ERR-TIMEFRAME-INVALID)
    (var-set lockup-duration new-duration)
    (log-transaction "lockup-updated" "token lockup period modified")
    (ok new-duration)))

;; DISTRIBUTION FUNCTIONS

;; Allow eligible recipients to claim their tokens
(define-public (redeem-tokens)
  (let (
    (user tx-sender)
    (tokens (var-get reward-size))
  )
    (asserts! (var-get distribution-active) ERR-DISTRIBUTION-PAUSED)
    (asserts! (is-some (map-get? whitelist user)) ERR-USER-NOT-ELIGIBLE)
    (asserts! (is-none (map-get? claim-ledger user)) ERR-TOKENS-ALREADY-CLAIMED)
    (asserts! (<= tokens (ft-get-balance reward-token admin-address)) ERR-TOKEN-SHORTAGE)
    (try! (ft-transfer? reward-token tokens admin-address user))
    (map-set claim-ledger user tokens)
    (var-set tokens-sent-total (+ (var-get tokens-sent-total) tokens))
    (log-transaction "tokens-claimed" "user claimed tokens")
    (ok tokens)))

;; Reclaim unclaimed tokens after the waiting period
(define-public (burn-unclaimed-tokens)
  (let (
    (current-block block-height)
    (unlock-block (+ (var-get launch-block) (var-get lockup-duration)))
  )
    (asserts! (is-eq tx-sender admin-address) ERR-ADMIN-ONLY)
    (asserts! (>= current-block unlock-block) ERR-RECLAIM-TIMING-INVALID)
    (let (
      (total-minted (ft-get-supply reward-token))
      (total-claimed (var-get tokens-sent-total))
      (unclaimed-balance (- total-minted total-claimed))
    )
      (try! (ft-burn? reward-token unclaimed-balance admin-address))
      (log-transaction "tokens-burned" "unclaimed tokens removed")
      (ok unclaimed-balance))))

;; READ-ONLY FUNCTIONS

;; Check if airdrop is currently active
(define-read-only (check-distribution-status)
  (var-get distribution-active))

;; Check if an address is eligible for the airdrop
(define-read-only (is-whitelisted (address principal))
  (default-to false (map-get? whitelist address)))

;; Check if a recipient has already claimed their tokens
(define-read-only (has-redeemed (address principal))
  (is-some (map-get? claim-ledger address)))

;; Get the amount claimed by a specific recipient
(define-read-only (get-redeemed-amount (address principal))
  (default-to u0 (map-get? claim-ledger address)))

;; Get the total number of tokens distributed so far
(define-read-only (get-total-distributed)
  (var-get tokens-sent-total))

;; Get the current token allocation per recipient
(define-read-only (get-reward-amount)
  (var-get reward-size))

;; Get the reclaim waiting period length
(define-read-only (get-lockup-period)
  (var-get lockup-duration))

;; Get the block when the airdrop began
(define-read-only (get-launch-block)
  (var-get launch-block))

;; Retrieve specific event information
(define-read-only (get-transaction-log (event-id uint))
  (map-get? event-history event-id))

;; Initialize the contract
(begin
  (ft-mint? reward-token u1000000000 admin-address))