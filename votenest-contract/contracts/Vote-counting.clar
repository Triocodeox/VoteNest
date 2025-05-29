;; Vote Counting Smart Contract
;; Handles vote tallying and results retrieval

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u101))
(define-constant ERR-VOTING-STILL-ACTIVE (err u102))
(define-constant ERR-ALREADY-VOTED (err u103))
(define-constant ERR-INVALID-OPTION (err u104))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Data structures
(define-map proposals
  { proposal-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    options: (list 10 (string-ascii 50)),
    voting-end-block: uint,
    total-votes: uint,
    is-finalized: bool
  }
)

;; Vote tallies per proposal and option
(define-map vote-tallies
  { proposal-id: uint, option-index: uint }
  { count: uint }
)

;; Track individual votes to prevent double voting
(define-map user-votes
  { proposal-id: uint, voter: principal }
  { option-index: uint, block-height: uint }
)

;; Proposal counter
(define-data-var proposal-counter uint u0)

;; Create a new proposal
(define-public (create-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (options (list 10 (string-ascii 50)))
  (voting-duration uint))
  (let
    (
      (proposal-id (+ (var-get proposal-counter) u1))
      (voting-end-block (+ stacks-block-height voting-duration))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len options) u1) (err u105)) ;; At least 2 options required
    
    ;; Store proposal
    (map-set proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        options: options,
        voting-end-block: voting-end-block,
        total-votes: u0,
        is-finalized: false
      }
    )
    
    ;; Initialize vote tallies for each option
    (map initialize-option-tally 
      (generate-sequence u0 (- (len options) u1))
      (list proposal-id proposal-id proposal-id proposal-id proposal-id 
            proposal-id proposal-id proposal-id proposal-id proposal-id))
    
    ;; Update counter
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

;; Helper function to initialize vote tallies
(define-private (initialize-option-tally (option-index uint) (proposal-id uint))
  (map-set vote-tallies
    { proposal-id: proposal-id, option-index: option-index }
    { count: u0 }
  )
)

;; Generate sequence helper (simplified for up to 10 options)
(define-private (generate-sequence (start uint) (end uint))
  (if (<= start end)
    (if (is-eq start u0) (list u0)
    (if (is-eq start u1) (list u0 u1)
    (if (is-eq start u2) (list u0 u1 u2)
    (if (is-eq start u3) (list u0 u1 u2 u3)
    (if (is-eq start u4) (list u0 u1 u2 u3 u4)
    (if (is-eq start u5) (list u0 u1 u2 u3 u4 u5)
    (if (is-eq start u6) (list u0 u1 u2 u3 u4 u5 u6)
    (if (is-eq start u7) (list u0 u1 u2 u3 u4 u5 u6 u7)
    (if (is-eq start u8) (list u0 u1 u2 u3 u4 u5 u6 u7 u8)
    (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9))))))))))
    (list)
  )
)

;; Cast a vote
(define-public (cast-vote (proposal-id uint) (option-index uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
      (current-tally (default-to { count: u0 } 
        (map-get? vote-tallies { proposal-id: proposal-id, option-index: option-index })))
    )
    ;; Validate voting is still active
    (asserts! (< stacks-block-height (get voting-end-block proposal)) ERR-VOTING-STILL-ACTIVE)
    
    ;; Check if user already voted
    (asserts! (is-none (map-get? user-votes { proposal-id: proposal-id, voter: tx-sender })) 
              ERR-ALREADY-VOTED)
    
    ;; Validate option index
    (asserts! (< option-index (len (get options proposal))) ERR-INVALID-OPTION)
    
    ;; Record the vote
    (map-set user-votes
      { proposal-id: proposal-id, voter: tx-sender }
      { option-index: option-index, block-height: stacks-block-height }
    )
    
    ;; Update vote tally
    (map-set vote-tallies
      { proposal-id: proposal-id, option-index: option-index }
      { count: (+ (get count current-tally) u1) }
    )
    
    ;; Update total votes in proposal
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { total-votes: (+ (get total-votes proposal) u1) })
    )
    
    (ok true)
  )
)

;; Finalize voting and tally results
(define-public (finalize-voting (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (>= stacks-block-height (get voting-end-block proposal)) ERR-VOTING-STILL-ACTIVE)
    (asserts! (not (get is-finalized proposal)) (err u106)) ;; Already finalized
    
    ;; Mark as finalized
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { is-finalized: true })
    )
    
    (ok true)
  )
)

;; Get vote count for a specific option
(define-read-only (get-option-votes (proposal-id uint) (option-index uint))
  (default-to u0 
    (get count (map-get? vote-tallies { proposal-id: proposal-id, option-index: option-index })))
)

;; Get complete results for a proposal
(define-read-only (get-proposal-results (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
      (options (get options proposal))
    )
    (ok {
      proposal-id: proposal-id,
      title: (get title proposal),
      total-votes: (get total-votes proposal),
      is-finalized: (get is-finalized proposal),
      voting-ended: (>= stacks-block-height (get voting-end-block proposal)),
      results: (map get-option-result-helper 
        (generate-sequence u0 (- (len options) u1))
        options)
    })
  )
)

;; Helper function to get result for each option
(define-private (get-option-result-helper (option-index uint) (option-text (string-ascii 50)))
  {
    option-index: option-index,
    option-text: option-text,
    vote-count: (get-option-votes (var-get proposal-counter) option-index)
  }
)

;; Get all results (for multiple proposals)
(define-read-only (get-all-results)
  (let
    (
      (total-proposals (var-get proposal-counter))
    )
    (ok {
      total-proposals: total-proposals,
      proposals: (map get-proposal-summary-helper 
        (generate-sequence u1 total-proposals))
    })
  )
)

;; Helper to get proposal summary
(define-private (get-proposal-summary-helper (proposal-id uint))
  (let
    (
      (proposal (unwrap-panic (map-get? proposals { proposal-id: proposal-id })))
    )
    {
      proposal-id: proposal-id,
      title: (get title proposal),
      total-votes: (get total-votes proposal),
      is-finalized: (get is-finalized proposal),
      voting-ended: (>= stacks-block-height (get voting-end-block proposal))
    }
  )
)

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

;; Check if user has voted
(define-read-only (has-user-voted (proposal-id uint) (voter principal))
  (is-some (map-get? user-votes { proposal-id: proposal-id, voter: voter }))
)

;; Get user's vote
(define-read-only (get-user-vote (proposal-id uint) (voter principal))
  (map-get? user-votes { proposal-id: proposal-id, voter: voter })
)

;; Get winning option (only after voting ends)
(define-read-only (get-winning-option (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
      (options (get options proposal))
    )
    (asserts! (>= stacks-block-height (get voting-end-block proposal)) ERR-VOTING-STILL-ACTIVE)
    
    ;; Find option with most votes (simplified for demonstration)
    (ok (fold find-max-votes 
      (generate-sequence u0 (- (len options) u1))
      { max-votes: u0, winning-option: u0 }))
  )
)

;; Helper to find option with maximum votes
(define-private (find-max-votes 
  (option-index uint) 
  (current-max { max-votes: uint, winning-option: uint }))
  (let
    (
      (option-votes (get-option-votes (var-get proposal-counter) option-index))
    )
    (if (> option-votes (get max-votes current-max))
      { max-votes: option-votes, winning-option: option-index }
      current-max
    )
  )
)