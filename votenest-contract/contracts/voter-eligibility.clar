;; Voter Eligibility and Whitelisting Contract
;; Supports multiple eligibility criteria for governance voting

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_VOTING_CLOSED (err u102))
(define-constant ERR_ALREADY_VOTED (err u103))
(define-constant ERR_NOT_ELIGIBLE (err u104))
(define-constant ERR_INVALID_PROPOSAL (err u105))
(define-constant ERR_INSUFFICIENT_TOKENS (err u106))
(define-constant ERR_NO_NFT_OWNERSHIP (err u107))

;; Data Variables
(define-data-var contract-admin principal CONTRACT_OWNER)
(define-data-var proposal-counter uint u0)

;; Data Maps

;; Proposal storage
(define-map proposals
  { proposal-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    creator: principal,
    start-block: uint,
    end-block: uint,
    eligibility-type: (string-ascii 20), ;; "whitelist", "token", "nft", "hybrid"
    min-token-amount: uint,
    required-nft-contract: (optional principal),
    yes-votes: uint,
    no-votes: uint,
    total-voters: uint,
    is-active: bool
  }
)

;; Whitelist per proposal
(define-map proposal-whitelist
  { proposal-id: uint, voter: principal }
  { is-whitelisted: bool }
)

;; Global whitelist (can be used across proposals)
(define-map global-whitelist
  { voter: principal }
  { is-whitelisted: bool, added-at: uint }
)

;; Vote tracking
(define-map votes
  { proposal-id: uint, voter: principal }
  { vote: bool, voted-at: uint }
)

;; Token eligibility settings
(define-map token-eligibility
  { proposal-id: uint }
  {
    token-contract: principal,
    min-amount: uint,
    snapshot-block: uint
  }
)

;; NFT eligibility settings
(define-map nft-eligibility
  { proposal-id: uint }
  {
    nft-contract: principal,
    required-trait: (string-ascii 50)
  }
)

;; Admin functions

;; Update contract admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (var-set contract-admin new-admin)
    (ok true)
  )
)

;; Proposal Management

;; Create a new proposal
(define-public (create-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (voting-duration uint)
  (eligibility-type (string-ascii 20))
  (min-token-amount uint)
  (nft-contract (optional principal))
)
  (let
    (
      (proposal-id (+ (var-get proposal-counter) u1))
      (start-block stacks-block-height)
      (end-block (+ stacks-block-height voting-duration))
    )
    (asserts! (> voting-duration u0) ERR_INVALID_PROPOSAL)
    
    ;; Store proposal
    (map-set proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        creator: tx-sender,
        start-block: start-block,
        end-block: end-block,
        eligibility-type: eligibility-type,
        min-token-amount: min-token-amount,
        required-nft-contract: nft-contract,
        yes-votes: u0,
        no-votes: u0,
        total-voters: u0,
        is-active: true
      }
    )
    
    ;; Update counter
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

;; Whitelist Management

;; Add voter to proposal-specific whitelist
(define-public (add-to-proposal-whitelist (proposal-id uint) (voter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? proposals { proposal-id: proposal-id })) ERR_PROPOSAL_NOT_FOUND)
    
    (map-set proposal-whitelist
      { proposal-id: proposal-id, voter: voter }
      { is-whitelisted: true }
    )
    (ok true)
  )
)

;; Remove voter from proposal-specific whitelist
(define-public (remove-from-proposal-whitelist (proposal-id uint) (voter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    
    (map-delete proposal-whitelist { proposal-id: proposal-id, voter: voter })
    (ok true)
  )
)

;; Add voter to global whitelist
(define-public (add-to-global-whitelist (voter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    
    (map-set global-whitelist
      { voter: voter }
      { is-whitelisted: true, added-at: stacks-block-height }
    )
    (ok true)
  )
)

;; Remove voter from global whitelist
(define-public (remove-from-global-whitelist (voter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    
    (map-delete global-whitelist { voter: voter })
    (ok true)
  )
)

;; Batch add to whitelist
(define-public (batch-add-to-whitelist (proposal-id uint) (voters (list 50 principal)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? proposals { proposal-id: proposal-id })) ERR_PROPOSAL_NOT_FOUND)
    
    (ok (map add-voter-to-whitelist voters))
  )
)

;; Helper function for batch operations
(define-private (add-voter-to-whitelist (voter principal))
  (map-set global-whitelist
    { voter: voter }
    { is-whitelisted: true, added-at: stacks-block-height }
  )
)

;; Eligibility Checking Functions

;; Check if voter is whitelisted for specific proposal
(define-read-only (is-whitelisted-for-proposal (proposal-id uint) (voter principal))
  (default-to false 
    (get is-whitelisted 
      (map-get? proposal-whitelist { proposal-id: proposal-id, voter: voter })
    )
  )
)

;; Check if voter is in global whitelist
(define-read-only (is-globally-whitelisted (voter principal))
  (default-to false 
    (get is-whitelisted 
      (map-get? global-whitelist { voter: voter })
    )
  )
)

;; Check token-based eligibility (placeholder for future integration)
(define-read-only (check-token-eligibility (proposal-id uint) (voter principal))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) false))
      (min-tokens (get min-token-amount proposal))
    )
    ;; Placeholder: In real implementation, this would check actual token balance
    ;; Example: (>= (contract-call? .token-contract get-balance voter) min-tokens)
    (>= min-tokens u0) ;; Always true for now - replace with actual token check
  )
)

;; Check NFT-based eligibility (placeholder for future integration)
(define-read-only (check-nft-eligibility (proposal-id uint) (voter principal))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) false))
      (nft-contract (get required-nft-contract proposal))
    )
    ;; Placeholder: In real implementation, this would check NFT ownership
    ;; Example: (is-some (contract-call? .nft-contract get-owner token-id))
    (is-some nft-contract) ;; Simplified check - replace with actual NFT verification
  )
)

;; Comprehensive eligibility check
(define-read-only (is-eligible-to-vote (proposal-id uint) (voter principal))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) false))
      (eligibility-type (get eligibility-type proposal))
    )
    (if (is-eq eligibility-type "whitelist")
      (or 
        (is-whitelisted-for-proposal proposal-id voter)
        (is-globally-whitelisted voter)
      )
      (if (is-eq eligibility-type "token")
        (check-token-eligibility proposal-id voter)
        (if (is-eq eligibility-type "nft")
          (check-nft-eligibility proposal-id voter)
          (if (is-eq eligibility-type "hybrid")
            (and
              (or 
                (is-whitelisted-for-proposal proposal-id voter)
                (is-globally-whitelisted voter)
              )
              (check-token-eligibility proposal-id voter)
            )
            false ;; Unknown eligibility type
          )
        )
      )
    )
  )
)

;; Voting Functions

;; Cast a vote
(define-public (vote (proposal-id uint) (vote-choice bool))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (voter tx-sender)
    )
    ;; Check if proposal is active and within voting period
    (asserts! (get is-active proposal) ERR_VOTING_CLOSED)
    (asserts! (>= stacks-block-height (get start-block proposal)) ERR_VOTING_CLOSED)
    (asserts! (<= stacks-block-height (get end-block proposal)) ERR_VOTING_CLOSED)
    
    ;; Check if voter hasn't already voted
    (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: voter })) ERR_ALREADY_VOTED)
    
    ;; Check eligibility
    (asserts! (is-eligible-to-vote proposal-id voter) ERR_NOT_ELIGIBLE)
    
    ;; Record vote
    (map-set votes
      { proposal-id: proposal-id, voter: voter }
      { vote: vote-choice, voted-at: stacks-block-height }
    )
    
    ;; Update vote counts
    (if vote-choice
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { yes-votes: (+ (get yes-votes proposal) u1) })
      )
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { no-votes: (+ (get no-votes proposal) u1) })
      )
    )
    
    ;; Update total voters
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { total-voters: (+ (get total-voters proposal) u1) })
    )
    
    (ok true)
  )
)

;; Close proposal (admin only)
(define-public (close-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
    
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { is-active: false })
    )
    (ok true)
  )
)

;; Read-only functions

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

;; Get vote for specific voter and proposal
(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

;; Get proposal results
(define-read-only (get-proposal-results (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) none))
    )
    (some {
      proposal-id: proposal-id,
      yes-votes: (get yes-votes proposal),
      no-votes: (get no-votes proposal),
      total-voters: (get total-voters proposal),
      is-active: (get is-active proposal)
    })
  )
)

;; Get current proposal counter
(define-read-only (get-proposal-counter)
  (var-get proposal-counter)
)

;; Check if address has voted on proposal
(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? votes { proposal-id: proposal-id, voter: voter }))
)

;; Get contract admin
(define-read-only (get-admin)
  (var-get contract-admin)
)
