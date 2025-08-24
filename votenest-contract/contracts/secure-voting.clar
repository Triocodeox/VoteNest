
;; title: secure-voting-contract
;; version: 2.0.0
;; summary: A cryptographic voting system with enhanced security and privacy
;; description: This contract implements a secure voting system using cryptographic commitments
;;              to ensure vote integrity and privacy while allowing verification.

;; Contract owner and administration
(define-data-var contract-owner principal tx-sender)
(define-data-var admin-list (list 10 principal) (list))

;; Voting parameters
(define-data-var election-name (string-ascii 100) "")
(define-data-var election-description (string-ascii 500) "")
(define-data-var start-block uint u0)
(define-data-var end-block uint u0)
(define-data-var reveal-end-block uint u0)
(define-data-var minimum-votes uint u1)
(define-data-var voting-state (string-ascii 20) "setup") ;; "setup", "voting", "revealing", "closed"

;; Vote data structures
(define-map vote-registry 
  { voter: principal } 
  { 
    vote-hash: (buff 32),
    vote-cast-block: uint,
    revealed: bool,
    revealed-option: (optional (buff 32)),
    valid: (optional bool)
  }
)

(define-map vote-counts
  { option: (buff 32) }
  { count: uint }
)

(define-data-var registered-voters (list 1000 principal) (list))
(define-data-var vote-options (list 50 {name: (string-utf8 50), hash: (buff 32)}) (list))
(define-data-var voter-count uint u0)
(define-data-var revealed-count uint u0)
(define-data-var verified-count uint u0)

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-WRONG-STATE (err u101))
(define-constant ERR-ALREADY-VOTED (err u102))
(define-constant ERR-INVALID-OPTION (err u103))
(define-constant ERR-NOT-REGISTERED (err u104))
(define-constant ERR-NOT-VOTED (err u105))
(define-constant ERR-ALREADY-REVEALED (err u106))
(define-constant ERR-OUTSIDE-TIMEFRAME (err u107))
(define-constant ERR-INVALID-HASH (err u108))
(define-constant ERR-INVALID-PARAMS (err u109))

;; Access control functions
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-admin)
  (or (is-contract-owner)
      (is-some (index-of (var-get admin-list) tx-sender)))
)

;; (define-private (require-admin)
;;   (asserts! (is-admin) ERR-UNAUTHORIZED)
;; )

;; Check if voter is registered
(define-private (is-registered-voter (user principal))
  (is-some (index-of (var-get registered-voters) user))
)

;; Check if voter has already cast a vote
(define-private (has-voted (user principal))
  (is-some (map-get? vote-registry {voter: user}))
)


;; Increment vote count for an option
(define-private (increment-vote-count (option (buff 32)))
  (let ((current-count (default-to u0 (get count (map-get? vote-counts {option: option})))))
    (map-set vote-counts 
      {option: option} 
      {count: (+ current-count u1)})
  )
)

;; Initialize contract and election details
(define-public (initialize-election 
  (name (string-ascii 100))
  (description (string-ascii 500))
  (options (list 50 {name: (string-ascii 50), hash: (buff 32)}))
  (start uint)
  (voting-duration uint)
  (reveal-duration uint)
  (min-votes uint))
  
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (asserts! (is-eq (var-get voting-state) "setup") ERR-WRONG-STATE)
    (asserts! (> (len options) u0) ERR-INVALID-PARAMS)
    (asserts! (>= start block-height) ERR-INVALID-PARAMS)
    (asserts! (> voting-duration u0) ERR-INVALID-PARAMS)
    (asserts! (> reveal-duration u0) ERR-INVALID-PARAMS)
    (asserts! (> min-votes u0) ERR-INVALID-PARAMS)
    
    (var-set election-name name)
    (var-set election-description description)
    (var-set start-block start)
    (var-set end-block (+ start voting-duration))
    (var-set reveal-end-block (+ (+ start voting-duration) reveal-duration))
    (var-set minimum-votes min-votes)
    
  
    (var-set voting-state "voting")
    (ok true)
  )
)


;; Remove an admin
(define-public (remove-admin (admin principal))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (asserts! (is-some (index-of (var-get admin-list) admin)) ERR-INVALID-PARAMS)
    
  
    (ok true)
  )
)

;; ;; Register voters (can only be done by admin)
;; (define-public (register-voters (voters (list 100 principal)))
;;   (begin
;;     (require-admin)
;;     (asserts! (or (is-eq (var-get voting-state) "setup") 
;;                  (is-eq (var-get voting-state) "voting")) 
;;               ERR-WRONG-STATE)

      
;;     (ok true)
;;   )
;; )

;; Cast a vote by submitting a cryptographic hash of the vote and salt
;; The hash should be: SHA256(vote_option + secret_salt)
(define-public (cast-vote (vote-hash (buff 32)))
  (begin
    (asserts! (is-eq (var-get voting-state) "voting") ERR-WRONG-STATE)
    (asserts! (is-registered-voter tx-sender) ERR-NOT-REGISTERED)
    (asserts! (not (has-voted tx-sender)) ERR-ALREADY-VOTED)
    (asserts! (and (>= block-height (var-get start-block)) 
                  (<= block-height (var-get end-block))) 
              ERR-OUTSIDE-TIMEFRAME)
    
    (map-set vote-registry 
      {voter: tx-sender} 
      {
        vote-hash: vote-hash,
        vote-cast-block: block-height,
        revealed: false,
        revealed-option: none,
        valid: none
      })
    
    (var-set voter-count (+ (var-get voter-count) u1))
    (ok vote-hash)
  )
)

;; ;; Transition to reveal phase
;; (define-public (start-reveal-phase)
;;   (begin
;;     (require-admin)
;;     (asserts! (is-eq (var-get voting-state) "voting") ERR-WRONG-STATE)
;;     (asserts! (>= block-height (var-get end-block)) ERR-OUTSIDE-TIMEFRAME)
;;     (asserts! (>= (var-get voter-count) (var-get minimum-votes)) ERR-INVALID-PARAMS)
    
;;     (var-set voting-state "revealing")
;;     (ok true)
;;   )
;; )

;; ;; Reveal and verify a vote
;; (define-public (reveal-vote (option (buff 32)) (salt (buff 32)))
;;   (let ((voter tx-sender)
;;         (vote-info (map-get? vote-registry {voter: tx-sender}))
;;         (computed-hash (sha256 (concat option salt))))
    
;;     (asserts! (is-eq (var-get voting-state) "revealing") ERR-WRONG-STATE)
;;     (asserts! (is-some vote-info) ERR-NOT-VOTED)
;;     (asserts! (not (get revealed (default-to 
;;                                  {vote-hash: 0x, vote-cast-block: u0, revealed: false, 
;;                                   revealed-option: none, valid: none} 
;;                                  vote-info))) 
;;               ERR-ALREADY-REVEALED)
;;     (asserts! (and (>= block-height (var-get end-block)) 
;;                   (<= block-height (var-get reveal-end-block))) 
;;               ERR-OUTSIDE-TIMEFRAME)
;;     (asserts! (is-valid-option option) ERR-INVALID-OPTION)
    
;;     (let ((stored-hash (get vote-hash (default-to 
;;                                       {vote-hash: 0x, vote-cast-block: u0, revealed: false, 
;;                                        revealed-option: none, valid: none} 
;;                                       vote-info)))
;;           (is-hash-valid (is-eq computed-hash stored-hash)))
      
;;       (if is-hash-valid
;;           (begin
;;             (map-set vote-registry 
;;               {voter: voter} 
;;               {
;;                 vote-hash: stored-hash,
;;                 vote-cast-block: (get vote-cast-block (default-to 
;;                                                      {vote-hash: 0x, vote-cast-block: u0, revealed: false, 
;;                                                       revealed-option: none, valid: none} 
;;                                                      vote-info)),
;;                 revealed: true,
;;                 revealed-option: (some option),
;;                 valid: (some true)
;;               })
            
;;             (increment-vote-count option)
;;             (var-set revealed-count (+ (var-get revealed-count) u1))
;;             (var-set verified-count (+ (var-get verified-count) u1))
;;             (ok true))
          
;;           (begin
;;             (map-set vote-registry 
;;               {voter: voter} 
;;               {
;;                 vote-hash: stored-hash,
;;                 vote-cast-block: (get vote-cast-block (default-to 
;;                                                      {vote-hash: 0x, vote-cast-block: u0, revealed: false, 
;;                                                       revealed-option: none, valid: none} 
;;                                                      vote-info)),
;;                 revealed: true,
;;                 revealed-option: (some option),
;;                 valid: (some false)
;;               })
            
;;             (var-set revealed-count (+ (var-get revealed-count) u1))
;;             (err ERR-INVALID-HASH))
;;       )
;;     )
;;   )
;; )

;; ;; Close voting and finalize results
;; (define-public (close-voting)
;;   (begin
;;     (require-admin)
;;     (asserts! (is-eq (var-get voting-state) "revealing") ERR-WRONG-STATE)
;;     (asserts! (>= block-height (var-get reveal-end-block)) ERR-OUTSIDE-TIMEFRAME)
    
;;     (var-set voting-state "closed")
;;     (ok true)
;;   )
;; )

;; Read-only functions to get election information
(define-read-only (get-election-info)
  (ok {
    name: (var-get election-name),
    description: (var-get election-description),
    state: (var-get voting-state),
    start-block: (var-get start-block),
    end-block: (var-get end-block),
    reveal-end-block: (var-get reveal-end-block),
    current-block: block-height,
    voter-count: (var-get voter-count),
    revealed-count: (var-get revealed-count),
    verified-count: (var-get verified-count),
    minimum-votes: (var-get minimum-votes)
  })
)

;; Get available voting options
(define-read-only (get-vote-options)
  (ok (var-get vote-options))
)

;; Get voter registration status
(define-read-only (is-voter-registered (voter principal))
  (ok (is-registered-voter voter))
)

;; Get voting status for a specific voter
(define-read-only (get-voter-status (voter principal))
  (ok (map-get? vote-registry {voter: voter}))
)

;; Get vote count for a specific option (only after reveal phase)
(define-read-only (get-vote-count (option (buff 32)))
  (begin
    (asserts! (or (is-eq (var-get voting-state) "revealing")
                 (is-eq (var-get voting-state) "closed")) 
              ERR-WRONG-STATE)
    (ok (default-to u0 (get count (map-get? vote-counts {option: option}))))
  )
)

;; ;; Get all final vote counts (only after voting is closed)
;; (define-read-only (get-all-vote-counts)
;;   (begin
;;     (asserts! (is-eq (var-get voting-state) "closed") ERR-WRONG-STATE)
;;     (let ((results (map (lambda (option) 
;;                           {
;;                             option-name: (get-option-name (get hash option)),
;;                             option-hash: (get hash option),
;;                             count: (default-to u0 (get count (map-get? vote-counts {option: (get hash option)})))
;;                           })
;;                         (var-get vote-options))))
;;       (ok results))
;;   )
;; )