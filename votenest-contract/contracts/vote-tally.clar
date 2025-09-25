;; Vote Tally Smart Contract
;; Handles vote counting, result storage, and dynamic tallying

;; ===== CONSTANTS =====
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-VOTING-ACTIVE (err u101))
(define-constant ERR-VOTING-ENDED (err u102))
(define-constant ERR-ALREADY-VOTED (err u103))
(define-constant ERR-INVALID-VOTE (err u104))
(define-constant ERR-NO-VOTES (err u105))
(define-constant ERR-TALLY-NOT-FINALIZED (err u106))
(define-constant ERR-INVALID-PROPOSAL (err u107))

;; Vote options
(define-constant VOTE-YES "yes")
(define-constant VOTE-NO "no")
(define-constant VOTE-ABSTAIN "abstain")

;; ===== DATA VARIABLES =====
(define-data-var voting-active bool true)
(define-data-var voting-ended bool false)
(define-data-var proposal-id uint u1)
(define-data-var total-eligible-voters uint u0)
(define-data-var tally-finalized bool false)
(define-data-var tally-timestamp uint u0)

;; Real-time vote counters (updated on each vote)
(define-data-var yes-votes uint u0)
(define-data-var no-votes uint u0)
(define-data-var abstain-votes uint u0)
(define-data-var total-votes-cast uint u0)

;; ===== DATA MAPS =====

;; Individual vote records
(define-map votes
    { voter: principal, proposal-id: uint }
    {
        choice: (string-ascii 10),
        cast-at: uint,
        block-height: uint,
        vote-weight: uint ;; For weighted voting systems
    }
)

;; Voter eligibility and status
(define-map eligible-voters
    { voter: principal }
    {
        is-eligible: bool,
        vote-weight: uint,
        registered-at: uint
    }
)

;; Final tally results (stored permanently after voting ends)
(define-map final-results
    { proposal-id: uint }
    {
        yes-count: uint,
        no-count: uint,
        abstain-count: uint,
        total-votes: uint,
        total-eligible: uint,
        turnout-percentage: uint,
        winning-option: (string-ascii 10),
        margin: uint,
        finalized-at: uint,
        finalized-by: principal
    }
)

;; Vote breakdown by categories (optional demographic analysis)
(define-map vote-breakdown
    { proposal-id: uint, category: (string-ascii 20) }
    {
        yes-count: uint,
        no-count: uint,
        abstain-count: uint,
        total-in-category: uint
    }
)

;; Historical tallies (snapshots during voting)
(define-map tally-snapshots
    { proposal-id: uint, snapshot-id: uint }
    {
        yes-count: uint,
        no-count: uint,
        abstain-count: uint,
        total-votes: uint,
        timestamp: uint,
        block-height: uint
    }
)

;; Proposal metadata
(define-map proposals
    { proposal-id: uint }
    {
        title: (string-ascii 256),
        description: (string-ascii 1024),
        created-by: principal,
        created-at: uint,
        voting-end-time: (optional uint),
        minimum-turnout: uint, ;; Minimum percentage for valid result
        is-active: bool
    }
)

;; ===== PUBLIC FUNCTIONS =====

;; Create a new proposal
(define-public (create-proposal 
    (title (string-ascii 256))
    (description (string-ascii 1024))
    (minimum-turnout uint))
    (let (
        (current-proposal-id (var-get proposal-id))
    )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        
        ;; Store proposal metadata
        (map-set proposals
            { proposal-id: current-proposal-id }
            {
                title: title,
                description: description,
                created-by: tx-sender,
                created-at: stacks-block-height,
                voting-end-time: none,
                minimum-turnout: minimum-turnout,
                is-active: true
            }
        )
        
        ;; Reset vote counters for new proposal
        (var-set yes-votes u0)
        (var-set no-votes u0)
        (var-set abstain-votes u0)
        (var-set total-votes-cast u0)
        (var-set voting-active true)
        (var-set voting-ended false)
        (var-set tally-finalized false)
        
        ;; Emit event
        (print {
            event: "proposal-created",
            proposal-id: current-proposal-id,
            title: title,
            minimum-turnout: minimum-turnout,
            created-at: stacks-block-height
        })
        
        (ok current-proposal-id)
    )
)

;; Register eligible voters
(define-public (register-voter (voter principal) (vote-weight uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        
        (map-set eligible-voters
            { voter: voter }
            {
                is-eligible: true,
                vote-weight: vote-weight,
                registered-at: stacks-block-height
            }
        )
        
        ;; Update total eligible voters count
        (var-set total-eligible-voters (+ (var-get total-eligible-voters) u1))
        
        (ok true)
    )
)

;; Cast a vote
(define-public (cast-vote (choice (string-ascii 10)))
    (let (
        (current-proposal-id (var-get proposal-id))
        (voter-data (unwrap! (map-get? eligible-voters { voter: tx-sender }) ERR-UNAUTHORIZED))
        (vote-weight (get vote-weight voter-data))
    )
        ;; Validation checks
        (asserts! (var-get voting-active) ERR-VOTING-ENDED)
        (asserts! (get is-eligible voter-data) ERR-UNAUTHORIZED)
        (asserts! (is-none (map-get? votes { voter: tx-sender, proposal-id: current-proposal-id })) ERR-ALREADY-VOTED)
        (asserts! (or (is-eq choice VOTE-YES) (is-eq choice VOTE-NO) (is-eq choice VOTE-ABSTAIN)) ERR-INVALID-VOTE)
        
        ;; Record the vote
        (map-set votes
            { voter: tx-sender, proposal-id: current-proposal-id }
            {
                choice: choice,
                cast-at: stacks-block-height,
                block-height: stacks-block-height,
                vote-weight: vote-weight
            }
        )
        
        ;; Update real-time tallies with weighted votes
        (if (is-eq choice VOTE-YES)
            (var-set yes-votes (+ (var-get yes-votes) vote-weight))
            (if (is-eq choice VOTE-NO)
                (var-set no-votes (+ (var-get no-votes) vote-weight))
                (var-set abstain-votes (+ (var-get abstain-votes) vote-weight))
            )
        )
        
        ;; Update total votes cast
        (var-set total-votes-cast (+ (var-get total-votes-cast) u1))
        
        ;; Emit vote event with current tally
        (print {
            event: "vote-cast",
            voter: tx-sender,
            proposal-id: current-proposal-id,
            choice: choice,
            vote-weight: vote-weight,
            current-tally: (get-live-tally)
        })
        
        (ok true)
    )
)

;; End voting period
(define-public (end-voting)
    (let (
        (current-proposal-id (var-get proposal-id))
        (existing-proposal (unwrap! (map-get? proposals { proposal-id: current-proposal-id }) ERR-INVALID-PROPOSAL))
    )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (var-get voting-active) ERR-VOTING-ENDED)
        
        ;; End voting
        (var-set voting-active false)
        (var-set voting-ended true)
        
        ;; Update proposal with end time
        (map-set proposals
            { proposal-id: current-proposal-id }
            (merge existing-proposal {
                voting-end-time: (some stacks-block-height),
                is-active: false
            })
        )
        
        ;; Emit event
        (print {
            event: "voting-ended",
            proposal-id: current-proposal-id,
            end-time: stacks-block-height,
            final-tally: (get-live-tally)
        })
        
        (ok true)
    )
)

;; Finalize tally and store permanent results
(define-public (finalize-tally)
    (let (
        (current-proposal-id (var-get proposal-id))
        (yes-count (var-get yes-votes))
        (no-count (var-get no-votes))
        (abstain-count (var-get abstain-votes))
        (total-votes (var-get total-votes-cast))
        (total-eligible (var-get total-eligible-voters))
        (turnout-pct (if (> total-eligible u0) (/ (* total-votes u100) total-eligible) u0))
        (winning-option (determine-winner yes-count no-count abstain-count))
        (margin (calculate-margin yes-count no-count abstain-count))
    )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (var-get voting-ended) ERR-VOTING-ACTIVE)
        (asserts! (not (var-get tally-finalized)) ERR-TALLY-NOT-FINALIZED)
        
        ;; Store final results permanently
        (map-set final-results
            { proposal-id: current-proposal-id }
            {
                yes-count: yes-count,
                no-count: no-count,
                abstain-count: abstain-count,
                total-votes: total-votes,
                total-eligible: total-eligible,
                turnout-percentage: turnout-pct,
                winning-option: winning-option,
                margin: margin,
                finalized-at: stacks-block-height,
                finalized-by: tx-sender
            }
        )
        
        ;; Mark as finalized
        (var-set tally-finalized true)
        (var-set tally-timestamp stacks-block-height)
        
        ;; Prepare for next proposal
        (var-set proposal-id (+ current-proposal-id u1))
        
        ;; Emit finalization event
        (print {
            event: "tally-finalized",
            proposal-id: current-proposal-id,
            results: {
                yes: yes-count,
                no: no-count,
                abstain: abstain-count,
                total: total-votes,
                turnout: turnout-pct,
                winner: winning-option,
                margin: margin
            },
            finalized-at: stacks-block-height
        })
        
        (ok {
            proposal-id: current-proposal-id,
            winner: winning-option,
            margin: margin,
            turnout: turnout-pct
        })
    )
)

;; Create a tally snapshot during voting
(define-public (create-tally-snapshot (snapshot-id uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        
        (map-set tally-snapshots
            { proposal-id: (var-get proposal-id), snapshot-id: snapshot-id }
            {
                yes-count: (var-get yes-votes),
                no-count: (var-get no-votes),
                abstain-count: (var-get abstain-votes),
                total-votes: (var-get total-votes-cast),
                timestamp: stacks-block-height,
                block-height: stacks-block-height
            }
        )
        
        (print {
            event: "tally-snapshot",
            proposal-id: (var-get proposal-id),
            snapshot-id: snapshot-id,
            tally: (get-live-tally)
        })
        
        (ok true)
    )
)

;; ===== PRIVATE FUNCTIONS =====

;; Determine winning option
(define-private (determine-winner (yes uint) (no uint) (abstain uint))
    (if (and (> yes no) (> yes abstain))
        VOTE-YES
        (if (and (> no yes) (> no abstain))
            VOTE-NO
            (if (and (> abstain yes) (> abstain no))
                VOTE-ABSTAIN
                "tie" ;; Handle tie case
            )
        )
    )
)

;; Calculate victory margin
(define-private (calculate-margin (yes uint) (no uint) (abstain uint))
    (let (
        (highest (if (and (>= yes no) (>= yes abstain))
                    yes
                    (if (>= no abstain) no abstain)))
        (second-highest (if (is-eq highest yes)
                           (if (>= no abstain) no abstain)
                           (if (is-eq highest no)
                              (if (>= yes abstain) yes abstain)
                              (if (>= yes no) yes no))))
    )
        (- highest second-highest)
    )
)

;; ===== READ-ONLY FUNCTIONS =====

;; Get live tally (dynamic, updates in real-time)
(define-read-only (get-live-tally)
    {
        proposal-id: (var-get proposal-id),
        yes-votes: (var-get yes-votes),
        no-votes: (var-get no-votes),
        abstain-votes: (var-get abstain-votes),
        total-votes: (var-get total-votes-cast),
        total-eligible: (var-get total-eligible-voters),
        turnout-percentage: (if (> (var-get total-eligible-voters) u0)
                               (/ (* (var-get total-votes-cast) u100) (var-get total-eligible-voters))
                               u0),
        voting-active: (var-get voting-active),
        voting-ended: (var-get voting-ended),
        tally-finalized: (var-get tally-finalized)
    }
)

;; Check if voter has voted
(define-read-only (has-voted (voter principal))
    (is-some (map-get? votes { voter: voter, proposal-id: (var-get proposal-id) }))
)

;; Get voter eligibility
(define-read-only (get-voter-eligibility (voter principal))
    (map-get? eligible-voters { voter: voter })
)

;; Get voting statistics
(define-read-only (get-voting-stats)
    {
        current-proposal: (var-get proposal-id),
        total-eligible-voters: (var-get total-eligible-voters),
        votes-cast: (var-get total-votes-cast),
        voting-active: (var-get voting-active),
        voting-ended: (var-get voting-ended),
        tally-finalized: (var-get tally-finalized),
        current-block: stacks-block-height
    }
)

;; Get detailed results with percentages
(define-read-only (get-detailed-results)
    (let (
        (total (var-get total-votes-cast))
        (yes (var-get yes-votes))
        (no (var-get no-votes))
        (abstain (var-get abstain-votes))
    )
        {
            votes: {
                yes: yes,
                no: no,
                abstain: abstain,
                total: total
            },
            percentages: {
                yes: (if (> total u0) (/ (* yes u100) total) u0),
                no: (if (> total u0) (/ (* no u100) total) u0),
                abstain: (if (> total u0) (/ (* abstain u100) total) u0)
            },
            turnout: (if (> (var-get total-eligible-voters) u0)
                        (/ (* total u100) (var-get total-eligible-voters))
                        u0),
            winner: (determine-winner yes no abstain),
            margin: (calculate-margin yes no abstain),
            is-finalized: (var-get tally-finalized)
        }
    )
)