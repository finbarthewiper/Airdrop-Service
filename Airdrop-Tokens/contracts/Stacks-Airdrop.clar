;; Token Airdrop Distribution Smart Contract
;;
;; A Clarity smart contract that manages token airdrops to eligible recipients.
;; Features include:
;; - Managing eligible recipient addresses
;; - Token claim functionality with eligibility verification
;; - Administrator controls for distribution parameters
;; - Reclaiming unclaimed tokens after a specified period
;; - Event logging for important contract actions

;; Define the token to be distributed
(define-fungible-token reward-token u1000000000)

;; Define admin constants and variables
(define-data-var admin-address principal tx-sender)

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
(define-constant ERR-OVERFLOW (err u109))
(define-constant ERR-ZERO-AMOUNT (err u110))
(define-constant ERR-MINT-FAILED (err u111))

;; Define airdrop state variables
(define-data-var distribution-active bool true)
(define-data-var tokens-sent-total uint u0)
(define-data-var reward-size uint u100)
(define-data-var launch-block uint block-height)
(define-data-var lockup-duration uint u10000) ;; Block count before unclaimed tokens can be reclaimed

;; Define recipient tracking maps
(define-map whitelist principal bool)
(define-map claim-ledger principal uint)

;; Event tracking system
(define-data-var event-id-counter uint u0)
(define-map event-history uint {event-type: (string-ascii 20), event-data: (string-ascii 256)})

;; Safe math helper function for addition - fixed to return a consistent type
(define-private (safe-add (a uint) (b uint))
  (let ((sum (+ a b)))
    (if (>= sum a) 
        sum
        (begin
          (print "Overflow detected")
          u0)))) ;; Return 0 on overflow rather than throwing an error

;; Record an event in the contract history
(define-private (log-transaction (event-type (string-ascii 20)) (event-data (string-ascii 256)))
  (let ((current-id (var-get event-id-counter)))
    (map-set event-history current-id {event-type: event-type, event-data: event-data})
    (var-set event-id-counter (+ current-id u1))
    current-id))

;; Check if sender is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin-address)))

;; ADMINISTRATION FUNCTIONS

;; Transfer ownership to a new admin
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR-ADMIN-ONLY)
    (var-set admin-address new-admin)
    (log-transaction "admin-transfer" "Admin rights transferred to new address")
    (ok true)))

;; Toggle distribution status (pause/unpause)
(define-public (toggle-distribution)
  (begin
    (asserts! (is-admin) ERR-ADMIN-ONLY)
    (let ((new-status (not (var-get distribution-active))))
      (var-set distribution-active new-status)
      (log-transaction "distribution" (if new-status "Distribution enabled" "Distribution disabled"))
      (ok new-status))))

;; Register a new eligible recipient
(define-public (whitelist-address (user principal))
  (begin
    (asserts! (is-admin) ERR-ADMIN-ONLY)
    (asserts! (is-none (map-get? whitelist user)) ERR-RECIPIENT-EXISTS)
    (map-set whitelist user true)
    (log-transaction "whitelist-add" "New recipient added to whitelist")
    (ok true)))

;; Remove a previously eligible recipient
(define-public (remove-from-whitelist (user principal))
  (begin
    (asserts! (is-admin) ERR-ADMIN-ONLY)
    (asserts! (is-some (map-get? whitelist user)) ERR-USER-NOT-ELIGIBLE)
    (map-delete whitelist user)
    (log-transaction "whitelist-remove" "Recipient removed from whitelist")
    (ok true)))

;; Register multiple recipients at once - completely rewritten for type safety
(define-public (batch-whitelist (users (list 50 principal)))
  (begin
    (asserts! (is-admin) ERR-ADMIN-ONLY)
    (log-transaction "batch-whitelist" "Multiple recipients added to whitelist")
    ;; Using map instead of fold for simplicity
    (ok (map add-user-to-whitelist users))))

;; Helper function for batch processing - simplified to avoid type issues
(define-private (add-user-to-whitelist (user principal))
  (begin
    (if (default-to false (map-get? whitelist user))
        true  ;; Already in whitelist, do nothing but return success
        (map-set whitelist user true))  ;; Add to whitelist
    true))  ;; Always return success for mapping

;; Change the token amount per recipient
(define-public (change-reward-amount (new-amount uint))
  (begin
    (asserts! (is-admin) ERR-ADMIN-ONLY)
    (asserts! (> new-amount u0) ERR-INVALID-TOKEN-AMOUNT)
    (var-set reward-size new-amount)
    (log-transaction "reward-updated" "Token reward amount changed")
    (ok new-amount)))

;; Adjust the reclaim waiting period
(define-public (update-lockup-period (new-duration uint))
  (begin
    (asserts! (is-admin) ERR-ADMIN-ONLY)
    (asserts! (> new-duration u0) ERR-TIMEFRAME-INVALID)
    (var-set lockup-duration new-duration)
    (log-transaction "lockup-updated" "Token lockup period modified")
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
    (asserts! (<= tokens (ft-get-balance reward-token (var-get admin-address))) ERR-TOKEN-SHORTAGE)
    
    ;; Transfer tokens
    (match (ft-transfer? reward-token tokens (var-get admin-address) user)
      success (begin
        (map-set claim-ledger user tokens)
        ;; Use safe-add for calculating total tokens sent
        (let ((new-total (safe-add (var-get tokens-sent-total) tokens)))
          ;; Check for overflow
          (asserts! (> new-total u0) ERR-OVERFLOW)
          (var-set tokens-sent-total new-total)
          (log-transaction "tokens-claimed" "User successfully claimed tokens")
          (ok tokens)))
      error (err error))))

;; Reclaim unclaimed tokens after the waiting period
(define-public (reclaim-unclaimed-tokens (destination principal))
  (let (
    (current-block block-height)
    (unlock-block (+ (var-get launch-block) (var-get lockup-duration)))
  )
    (asserts! (is-admin) ERR-ADMIN-ONLY)
    (asserts! (>= current-block unlock-block) ERR-RECLAIM-TIMING-INVALID)
    
    ;; Calculate tokens that can be reclaimed
    (let (
      (remaining-balance (ft-get-balance reward-token (var-get admin-address)))
    )
      (asserts! (> remaining-balance u0) ERR-ZERO-AMOUNT)
      (match (ft-transfer? reward-token remaining-balance (var-get admin-address) destination)
        success (begin
          (log-transaction "tokens-reclaimed" "Unclaimed tokens reclaimed")
          (ok remaining-balance))
        error (err error)))))

;; READ-ONLY FUNCTIONS

;; Get current admin address
(define-read-only (get-admin)
  (var-get admin-address))

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

;; Initialize the contract properly with response handling
(define-private (initialize-contract)
  (begin
    ;; Mint tokens first
    (match (ft-mint? reward-token u1000000000 tx-sender)
      success (begin
        (log-transaction "contract-init" "Airdrop contract initialized")
        true)
      error false)))

;; Call initialization function at contract deployment
(initialize-contract)