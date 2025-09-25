;; Proposal Management Contract
;; Handles creation, storage, and management of proposals

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u404))
(define-constant ERR-INVALID-PROPOSAL (err u400))
(define-constant ERR-PROPOSAL-EXPIRED (err u410))
(define-constant ERR-PROPOSAL-NOT-STARTED (err u411))
(define-constant ERR-INVALID-VOTING-PERIOD (err u412))
(define-constant ERR-EMPTY-TITLE (err u413))
(define-constant ERR-EMPTY-DESCRIPTION (err u414))
(define-constant ERR-INVALID-OPTIONS (err u415))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Data variables
(define-data-var proposal-counter uint u0)
(define-data-var min-voting-period uint u144) ;; ~24 hours in blocks
(define-data-var max-voting-period uint u4320) ;; ~30 days in blocks

;; Authorization map
(define-map authorized-proposers principal bool)

;; Proposal status constants
(define-constant STATUS-PENDING u0)
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-EXPIRED u2)
(define-constant STATUS-EXECUTED u3)
(define-constant STATUS-CANCELLED u4)

;; Proposal data structure
(define-map proposals uint {
    id: uint,
    title: (string-ascii 200),
    description: (string-ascii 1000),
    proposer: principal,
    voting-options: (list 10 (string-ascii 100)),
    start-block-height: uint,
    end-block-height: uint,
    created-at: uint,
    status: uint,
    votes-for: uint,
    votes-against: uint,
    votes-abstain: uint,
    total-votes: uint,
    execution-delay: uint,
    category: (string-ascii 50),
    required-threshold: uint,
    metadata: (string-ascii 500)
})

;; Proposal categories map
(define-map proposal-categories (string-ascii 50) {
    name: (string-ascii 50),
    description: (string-ascii 200),
    min-threshold: uint,
    voting-period: uint,
    execution-delay: uint
})

;; Proposal votes tracking
(define-map proposal-votes {proposal-id: uint, voter: principal} {
    vote-option: uint,
    voting-power: uint,
    voted-at: uint
})

;; Proposal execution tracking
(define-map proposal-executions uint {
    executed-at: uint,
    executor: principal,
    execution-hash: (buff 32),
    success: bool
})

;; Initialize default categories
(map-set proposal-categories "governance" {
    name: "governance",
    description: "General governance proposals",
    min-threshold: u1000,
    voting-period: u1440, ;; ~10 days
    execution-delay: u144 ;; ~1 day
})

(map-set proposal-categories "parameter" {
    name: "parameter",
    description: "Contract parameter changes",
    min-threshold: u2000,
    voting-period: u2160, ;; ~15 days
    execution-delay: u288 ;; ~2 days
})

(map-set proposal-categories "emergency" {
    name: "emergency",
    description: "Emergency proposals",
    min-threshold: u500,
    voting-period: u720, ;; ~5 days
    execution-delay: u72 ;; ~12 hours
})

;; Read-only functions

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

;; Get proposal count
(define-read-only (get-proposal-count)
    (var-get proposal-counter)
)

;; Get proposal status
(define-read-only (get-proposal-status (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (let ((current-block block-height)
                      (start-block (get start-block-height proposal))
                      (end-block (get end-block-height proposal))
                      (stored-status (get status proposal)))
            (if (is-eq stored-status STATUS-EXECUTED)
                STATUS-EXECUTED
                (if (is-eq stored-status STATUS-CANCELLED)
                    STATUS-CANCELLED
                    (if (< current-block start-block)
                        STATUS-PENDING
                        (if (<= current-block end-block)
                            STATUS-ACTIVE
                            STATUS-EXPIRED)))))
        u999 ;; Return uint instead of (some u999) to match other arm types
    )
)

;; Check if user is authorized to create proposals
(define-read-only (is-authorized-proposer (user principal))
    (or (is-eq user CONTRACT-OWNER)
        (default-to false (map-get? authorized-proposers user)))
)

;; Get proposal category details
(define-read-only (get-proposal-category (category (string-ascii 50)))
    (map-get? proposal-categories category)
)

;; Get user vote for proposal
(define-read-only (get-user-vote (proposal-id uint) (user principal))
    (map-get? proposal-votes {proposal-id: proposal-id, voter: user})
)

;; Get proposal execution details
(define-read-only (get-proposal-execution (proposal-id uint))
    (map-get? proposal-executions proposal-id)
)

;; Check if proposal can be executed
(define-read-only (can-execute-proposal (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (let ((current-status (get-proposal-status proposal-id))
                      (execution-delay (get execution-delay proposal))
                      (end-block (get end-block-height proposal)))
            (and (is-eq current-status STATUS-EXPIRED)
                 (> block-height (+ end-block execution-delay))
                 (>= (get votes-for proposal) (get required-threshold proposal))))
        false
    )
)

;; Public functions

;; Create a new proposal
(define-public (create-proposal 
    (title (string-ascii 200))
    (description (string-ascii 1000))
    (voting-options (list 10 (string-ascii 100)))
    (voting-period uint)
    (category (string-ascii 50))
    (metadata (string-ascii 500)))
    (let ((proposal-id (+ (var-get proposal-counter) u1))
          (current-block block-height)
          (category-info (unwrap! (map-get? proposal-categories category) ERR-INVALID-PROPOSAL)))
        
        ;; Validate authorization
        (asserts! (is-authorized-proposer tx-sender) ERR-NOT-AUTHORIZED)
        
        ;; Validate inputs
        (asserts! (> (len title) u0) ERR-EMPTY-TITLE)
        (asserts! (> (len description) u0) ERR-EMPTY-DESCRIPTION)
        (asserts! (> (len voting-options) u0) ERR-INVALID-OPTIONS)
        (asserts! (and (>= voting-period (var-get min-voting-period))
                      (<= voting-period (var-get max-voting-period))) ERR-INVALID-VOTING-PERIOD)
        
        ;; Create proposal
        (map-set proposals proposal-id {
            id: proposal-id,
            title: title,
            description: description,
            proposer: tx-sender,
            voting-options: voting-options,
            start-block-height: (+ current-block u10), ;; Start in 10 blocks
            end-block-height: (+ current-block u10 voting-period),
            created-at: current-block,
            status: STATUS-PENDING,
            votes-for: u0,
            votes-against: u0,
            votes-abstain: u0,
            total-votes: u0,
            execution-delay: (get execution-delay category-info),
            category: category,
            required-threshold: (get min-threshold category-info),
            metadata: metadata
        })
        
        ;; Update counter
        (var-set proposal-counter proposal-id)
        
        (ok proposal-id)
    )
)

;; Update proposal status (admin only)
(define-public (update-proposal-status (proposal-id uint) (new-status uint))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND)))
        
        ;; Only contract owner can update status
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        ;; Update proposal
        (map-set proposals proposal-id (merge proposal {status: new-status}))
        
        (ok true)
    )
)

;; Cancel proposal (proposer or admin only)
(define-public (cancel-proposal (proposal-id uint))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
          (current-status (get-proposal-status proposal-id)))
        
        ;; Only proposer or contract owner can cancel
        (asserts! (or (is-eq tx-sender (get proposer proposal))
                     (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
        
        ;; Can only cancel pending or active proposals
        (asserts! (or (is-eq current-status STATUS-PENDING)
                     (is-eq current-status STATUS-ACTIVE)) ERR-PROPOSAL-EXPIRED)
        
        ;; Update status to cancelled
        (map-set proposals proposal-id (merge proposal {status: STATUS-CANCELLED}))
        
        (ok true)
    )
)

;; Add authorized proposer (admin only)
(define-public (add-authorized-proposer (user principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (map-set authorized-proposers user true)
        (ok true)
    )
)

;; Remove authorized proposer (admin only)
(define-public (remove-authorized-proposer (user principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (map-delete authorized-proposers user)
        (ok true)
    )
)

;; Update voting parameters (admin only)
(define-public (update-voting-parameters (min-period uint) (max-period uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (< min-period max-period) ERR-INVALID-VOTING-PERIOD)
        
        (var-set min-voting-period min-period)
        (var-set max-voting-period max-period)
        
        (ok true)
    )
)

;; Add or update proposal category (admin only)
(define-public (set-proposal-category 
    (category (string-ascii 50))
    (name (string-ascii 50))
    (description (string-ascii 200))
    (min-threshold uint)
    (voting-period uint)
    (execution-delay uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        (map-set proposal-categories category {
            name: name,
            description: description,
            min-threshold: min-threshold,
            voting-period: voting-period,
            execution-delay: execution-delay
        })
        
        (ok true)
    )
)

;; Execute proposal (anyone can call if conditions are met)
(define-public (execute-proposal (proposal-id uint) (execution-hash (buff 32)))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND)))
        
        ;; Check if proposal can be executed
        (asserts! (can-execute-proposal proposal-id) ERR-NOT-AUTHORIZED)
        
        ;; Mark as executed
        (map-set proposals proposal-id (merge proposal {status: STATUS-EXECUTED}))
        
        ;; Record execution details
        (map-set proposal-executions proposal-id {
            executed-at: block-height,
            executor: tx-sender,
            execution-hash: execution-hash,
            success: true
        })
        
        (ok true)
    )
)

;; Batch get proposals
(define-read-only (get-proposals-batch (start-id uint) (count uint))
    (let ((end-id (+ start-id count)))
        (map get-proposal (list start-id (+ start-id u1) (+ start-id u2) (+ start-id u3) (+ start-id u4)))
    )
)
